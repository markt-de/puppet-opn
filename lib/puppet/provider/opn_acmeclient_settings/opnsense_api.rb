# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/id_resolver'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_acmeclient_settings).provide(:opnsense_api) do
  desc 'Manages OPNsense ACME Client global settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Delegates reconfigure to ServiceReconfigure after all opn_acmeclient_settings
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:acmeclient].run
  end

  def self.relation_fields
    {
      'UpdateCron'        => { endpoint: 'cron/settings/search_jobs', multiple: false, name_field: 'description' },
      'haproxyAclRef'     => { endpoint: 'haproxy/settings/search_acls', multiple: false },
      'haproxyActionRef'  => { endpoint: 'haproxy/settings/search_actions', multiple: false },
      'haproxyServerRef'  => { endpoint: 'haproxy/settings/search_servers', multiple: false },
      'haproxyBackendRef' => { endpoint: 'haproxy/settings/search_backends', multiple: false },
    }.freeze
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('acmeclient/settings/get')
      data     = response.dig('acmeclient', 'settings') || {}

      config = normalize_config(data)
      config = PuppetX::Opn::IdResolver.translate_to_names(
        client, device_name, relation_fields, config
      )

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_acmeclient_settings: failed to fetch from '#{device_name}': #{e.message}")
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
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, resource[:name], self.class.relation_fields, config
    )

    result = client.post('acmeclient/settings/set', { 'acmeclient' => { 'settings' => config } })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_acmeclient_settings: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    PuppetX::Opn::ServiceReconfigure[:acmeclient].mark(resource[:name], client)
  end
end
