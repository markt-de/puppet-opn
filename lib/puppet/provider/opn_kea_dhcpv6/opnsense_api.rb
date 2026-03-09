# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_kea_dhcpv6).provide(:opnsense_api) do
  desc 'Manages OPNsense KEA DHCPv6 global settings via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :kea

  # Managed sections: general (service config), lexpire (lease expiration),
  # ha (high availability)
  def self.settings_sections
    ['general', 'lexpire', 'ha'].freeze
  end

  # Delegates reconfigure to ServiceReconfigure after all opn_kea_dhcpv6
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:kea].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('kea/dhcpv6/get')
      data     = response['dhcpv6'] || {}

      # Extract only the managed sections and normalize selection hashes
      # (interfaces in general section)
      config = data.slice(*settings_sections)
      config = normalize_config(config)

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_kea_dhcpv6: failed to fetch from '#{device_name}': #{e.message}")
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

  # Singleton provider: namevar is the device name itself (no '@' separator),
  # so we override the mixin's api_client to use resource[:name] directly.
  def api_client
    self.class.api_client(resource[:name])
  end

  # Save DHCPv6 settings via the set endpoint
  def save_settings(client, config)
    result = client.post('kea/dhcpv6/set', { 'dhcpv6' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_kea_dhcpv6: failed to save settings for '#{resource[:name]}': #{result.inspect}"
  end

  # Save settings and mark the device for reconfigure
  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    PuppetX::Opn::ServiceReconfigure[:kea].mark(resource[:name], client)
  end
end
