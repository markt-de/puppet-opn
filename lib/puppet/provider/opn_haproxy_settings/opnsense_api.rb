# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

Puppet::Type.type(:opn_haproxy_settings).provide(:opnsense_api) do
  desc 'Manages OPNsense HAProxy global settings via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

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
      config = PuppetX::Opn::HaproxyUuidResolver.translate_to_names(
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

  def self.prefetch(resources)
    all_instances = instances
    resources.each do |name, resource|
      provider = all_instances.find { |inst| inst.name == name }
      resource.provider = provider if provider
    end
  end

  def self.post_resource_eval
    PuppetX::Opn::HaproxyReconfigure.run
  end

  def self.normalize_config(obj)
    return obj unless obj.is_a?(Hash)
    return normalize_selection(obj) if selection_hash?(obj)

    obj.transform_values { |v| normalize_config(v) }
  end

  def self.selection_hash?(hash)
    hash.is_a?(Hash) &&
      !hash.empty? &&
      hash.values.all? { |v| v.is_a?(Hash) && v.key?('value') && v.key?('selected') }
  end

  def self.normalize_selection(hash)
    hash.select { |_k, v| v['selected'].to_i == 1 }.keys.join(',')
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    apply_config(resource[:config] || {})
  end

  def destroy
    client = api_client
    save_settings(client, {})
    mark_reconfigure(client)
    @property_hash.clear
  rescue
    PuppetX::Opn::HaproxyReconfigure.mark_error(resource[:name])
    raise
  end

  def config
    @property_hash[:config]
  end

  def config=(value)
    @pending_config = value
  end

  def flush
    return unless @pending_config

    apply_config(@pending_config)
  end

  private

  def api_client
    self.class.api_client(resource[:name])
  end

  def save_settings(client, config)
    config = PuppetX::Opn::HaproxyUuidResolver.translate_to_uuids(
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
  rescue
    PuppetX::Opn::HaproxyReconfigure.mark_error(resource[:name])
    raise
  end

  def mark_reconfigure(client)
    PuppetX::Opn::HaproxyReconfigure.mark(resource[:name], client)
  end
end
