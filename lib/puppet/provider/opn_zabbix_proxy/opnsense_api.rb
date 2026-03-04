# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'

Puppet::Type.type(:opn_zabbix_proxy).provide(:opnsense_api) do
  desc 'Manages OPNsense Zabbix Proxy settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Fetches the current Zabbix Proxy configuration for every configured device.
  # Uses GET /api/zabbixproxy/general/get which returns { "general": { ... } }.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('zabbixproxy/general/get')
      settings = response['general'] || {}

      instances << new(
        ensure: :present,
        name:   device_name,
        config: settings,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_zabbix_proxy: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  # Called when ensure => present and no current instance exists (plugin not installed
  # or API unreachable). Applies the desired config and triggers a reconfigure.
  def create
    apply_config(resource[:config] || {})
  end

  # Called when ensure => absent. Disables the proxy service.
  def destroy
    config = (@property_hash[:config] || {}).merge('enabled' => '0')
    client = api_client
    save_settings(client, config)
    reconfigure(client)
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
    result = client.post('zabbixproxy/general/set', { 'general' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_zabbix_proxy: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    reconfigure(client)
  end

  def reconfigure(client)
    reconf = client.post('zabbixproxy/service/reconfigure', {})
    status = reconf.is_a?(Hash) ? reconf['status'].to_s.strip.downcase : nil
    if status == 'ok'
      Puppet.notice("opn_zabbix_proxy: reconfigure of '#{resource[:name]}' completed")
    else
      Puppet.warning(
        "opn_zabbix_proxy: reconfigure of '#{resource[:name]}' returned " \
        "unexpected status: #{reconf.inspect}",
      )
    end
  end
end
