# frozen_string_literal: true

require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_haproxy_settings).provide(:opnsense_api) do
  desc 'Manages OPNsense HAProxy global settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :haproxy

  def self.relation_fields
    {
      'general.stats.allowedUsers'             => { endpoint: 'haproxy/settings/search_users',  multiple: true },
      'general.stats.allowedGroups'            => { endpoint: 'haproxy/settings/search_groups', multiple: true },
      'maintenance.cronjobs.syncCertsCron'     => { endpoint: 'cron/settings/search_jobs', multiple: false, name_field: 'description' },
      'maintenance.cronjobs.updateOcspCron'    => { endpoint: 'cron/settings/search_jobs', multiple: false, name_field: 'description' },
      'maintenance.cronjobs.reloadServiceCron' => { endpoint: 'cron/settings/search_jobs', multiple: false, name_field: 'description' },
      'maintenance.cronjobs.restartServiceCron' => { endpoint: 'cron/settings/search_jobs', multiple: false, name_field: 'description' },
    }.freeze
  end

  def self.settings_sections
    ['general', 'maintenance'].freeze
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('haproxy/settings/get')
      data     = response['haproxy'] || {}

      config = data.slice(*settings_sections)
      config = normalize_config(config)
      config = PuppetX::Opn::IdResolver.translate_to_names(
        client, device_name, relation_fields, config
      )

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_haproxy_settings: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:haproxy].run
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

  # Singleton provider: namevar is the device name itself (no '@' separator),
  # so we override the mixin's api_client to use resource[:name] directly.
  def api_client
    self.class.api_client(resource[:name])
  end

  def save_settings(client, config)
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, resource[:name], self.class.relation_fields, config
    )

    result = client.post('haproxy/settings/set', { 'haproxy' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_haproxy_settings: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  def mark_reconfigure(client)
    PuppetX::Opn::ServiceReconfigure[:haproxy].mark(resource[:name], client)
  end
end
