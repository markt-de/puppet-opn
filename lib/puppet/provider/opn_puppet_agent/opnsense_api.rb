# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_puppet_agent).provide(:opnsense_api) do
  desc 'Manages OPNsense Puppet Agent settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :puppet_agent

  # Delegates reconfigure to ServiceReconfigure after all opn_puppet_agent
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:puppet_agent].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('puppetagent/settings/get')
      data     = response['general'] || {}

      config = normalize_config(data)

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_puppet_agent: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    apply_config(resource[:config] || {})
  end

  def destroy
    client = api_client
    save_settings(client, {})
    mark_reconfigure(client)
    @property_hash.clear
  end

  def flush
    return unless @pending_config

    apply_config(@pending_config)
  end

  private

  # Singleton override: uses resource[:name] directly as device name
  # since singletons don't store device in @property_hash.
  def api_client
    self.class.api_client(resource[:name])
  end

  def save_settings(client, config)
    result = client.post('puppetagent/settings/set', { 'general' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_puppet_agent: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    PuppetX::Opn::ServiceReconfigure[:puppet_agent].mark(resource[:name], client)
  end
end
