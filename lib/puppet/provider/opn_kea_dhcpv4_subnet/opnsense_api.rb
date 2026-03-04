# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_kea_dhcpv4_subnet).provide(:opnsense_api) do
  desc 'Manages OPNsense KEA DHCPv4 subnets via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Delegates reconfigure to ServiceReconfigure after all opn_kea_dhcpv4_subnet
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:kea].run
  end

  # Uses search+get pattern: searchSubnet returns limited columns,
  # getSubnet/{uuid} returns the full configuration including option_data.
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('kea/dhcpv4/searchSubnet', {})
      rows     = response['rows'] || []

      rows.each do |row|
        uuid = row['uuid']
        # Fetch full subnet details (option_data, pools, allocator, etc.)
        detail = client.get("kea/dhcpv4/getSubnet/#{uuid}")
        item_data = normalize_config(detail['subnet4'] || {})

        # Subnet CIDR is the identifier
        item_name = item_data['subnet'].to_s
        next if item_name.empty?

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   uuid,
          config: item_data.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_kea_dhcpv4_subnet: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client    = api_client
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    # Inject the subnet CIDR from the resource title
    config['subnet'] = item_name

    result = client.post('kea/dhcpv4/addSubnet', { 'subnet4' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_kea_dhcpv4_subnet: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("kea/dhcpv4/delSubnet/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_kea_dhcpv4_subnet: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  def flush
    return unless @pending_config

    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    # Inject the subnet CIDR from the resource title
    config['subnet'] = item_name

    result = client.post("kea/dhcpv4/setSubnet/#{uuid}", { 'subnet4' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_kea_dhcpv4_subnet: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:kea].mark(device, client)
  end
end
