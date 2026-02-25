# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/zabbix_agent_reconfigure'

Puppet::Type.type(:opn_zabbix_agent).provide(:opnsense_api) do
  desc 'Manages OPNsense Zabbix Agent settings via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches the current Zabbix Agent configuration for every configured device.
  # Uses GET /api/zabbixagent/settings/get which returns:
  #   { "zabbixagent": { "local": {...}, "settings": {...}, ... } }
  #
  # Only the non-array sections (local, settings) are stored in config.
  # Userparameters and aliases are managed by separate resource types.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
        client   = api_client(device_name)
        response = client.get('zabbixagent/settings/get')
        data     = response['zabbixagent'] || {}

        config = data.reject { |k, _| %w[userparameters aliases].include?(k) }
        config = normalize_config(config)

        instances << new(
          ensure: :present,
          name:   device_name,
          config: config,
        )
      rescue Puppet::Error => e
        Puppet.warning("opn_zabbix_agent: failed to fetch from '#{device_name}': #{e.message}")
      end
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

  # Called once after ALL opn_zabbix_agent* resources are evaluated.
  # Delegates to shared module — first call does the work, rest are no-ops.
  def self.post_resource_eval
    PuppetX::Opn::ZabbixAgentReconfigure.run
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  # Called when ensure => present and no current instance was found.
  def create
    apply_config(resource[:config] || {})
  end

  # Called when ensure => absent. Disables the agent service.
  def destroy
    config = deep_merge(@property_hash[:config] || {}, 'settings' => { 'main' => { 'enabled' => '0' } })
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
    @property_hash.clear
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
    result = client.post('zabbixagent/settings/set', { 'zabbixagent' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_zabbix_agent: failed to save settings for '#{resource[:name]}': #{result.inspect}"
    end
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  def mark_reconfigure(client)
    PuppetX::Opn::ZabbixAgentReconfigure.mark(resource[:name], client)
  end

  # Recursively merges two hashes (right takes precedence for scalar values).
  def deep_merge(base, overlay)
    base.merge(overlay) do |_key, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        deep_merge(old_val, new_val)
      else
        new_val
      end
    end
  end

  # Class-level helpers for normalizing OPNsense selection hashes.
  # The GET endpoint returns OptionField, CSVListField and NetworkField (AsList)
  # values as: { "key" => { "value" => "...", "selected" => 0|1 }, ... }
  # normalize_config collapses these to the plain strings the POST endpoint
  # accepts, so deep_match? in the type's insync? can compare correctly.
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

  # Joins the selected keys with "," (preserving insertion order).
  # Single selection → plain string; multiple → comma-separated string.
  def self.normalize_selection(hash)
    hash.select { |_k, v| v['selected'].to_i == 1 }.keys.join(',')
  end
end
