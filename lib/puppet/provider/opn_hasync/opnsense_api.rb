# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_hasync).provide(:opnsense_api) do
  desc 'Manages OPNsense HA sync settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Delegates reconfigure to ServiceReconfigure after all opn_hasync
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:hasync].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('core/hasync/get')
      data     = response['hasync'] || {}

      config = normalize_config(data)

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_hasync: failed to fetch from '#{device_name}': #{e.message}")
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
    result = client.post('core/hasync/set', { 'hasync' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_hasync: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    PuppetX::Opn::ServiceReconfigure[:hasync].mark(resource[:name], client)
  end
end
