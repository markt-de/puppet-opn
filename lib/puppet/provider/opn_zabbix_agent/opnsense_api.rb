# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_zabbix_agent).provide(:opnsense_api) do
  desc 'Manages OPNsense Zabbix Agent settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

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
      client   = api_client(device_name)
      response = client.get('zabbixagent/settings/get')
      data     = response['zabbixagent'] || {}

      config = data.reject { |k, _| ['userparameters', 'aliases'].include?(k) }
      config = normalize_config(config)

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_zabbix_agent: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  # Called once after ALL opn_zabbix_agent* resources are evaluated.
  # Delegates to shared module — first call does the work, rest are no-ops.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:zabbix_agent].run
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

  def flush
    return unless @pending_config

    apply_config(@pending_config)
  end

  private

  # Singleton provider: namevar is the device name itself (no '@' separator),
  # so we use resource[:name] directly instead of the default device lookup.
  def api_client
    self.class.api_client(resource[:name])
  end

  def save_settings(client, config)
    result = client.post('zabbixagent/settings/set', { 'zabbixagent' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_zabbix_agent: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  def mark_reconfigure(client)
    PuppetX::Opn::ServiceReconfigure[:zabbix_agent].mark(resource[:name], client)
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
end
