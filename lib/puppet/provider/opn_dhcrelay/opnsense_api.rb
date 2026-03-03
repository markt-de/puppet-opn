# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/dhcrelay_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

Puppet::Type.type(:opn_dhcrelay).provide(:opnsense_api) do
  desc 'Manages OPNsense DHCP Relay instances via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.relation_fields
    {
      'destination' => { endpoint: 'dhcrelay/settings/search_dest', multiple: false },
    }
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('dhcrelay/settings/search_relay', {})
      rows     = response['rows'] || []

      rows.each do |row|
        relay_interface = row['interface'].to_s
        next if relay_interface.empty?

        config = PuppetX::Opn::HaproxyUuidResolver.translate_to_names(
          client, device_name, relation_fields,
          row.reject { |k, _| k == 'uuid' }
        )

        inst = new(
          ensure: :present,
          name:   "#{relay_interface}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: config,
        )
        inst.instance_variable_set(:@relay_interface, relay_interface)
        inst.instance_variable_set(:@device_name, device_name)
        instances << inst
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_dhcrelay: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  attr_reader :relay_interface, :device_name

  def self.prefetch(resources)
    all_instances = instances
    resources.each_value do |resource|
      device = resource[:device]
      iface  = (resource[:config] || {})['interface'].to_s

      provider = all_instances.find do |inst|
        inst.device_name == device && inst.relay_interface == iface
      end
      resource.provider = provider if provider
    end
  end

  def self.post_resource_eval
    PuppetX::Opn::DhcrelayReconfigure.run
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    client = api_client
    device = @property_hash[:device] || resource[:device]
    config = (resource[:config] || {}).dup
    config = PuppetX::Opn::HaproxyUuidResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post('dhcrelay/settings/add_relay', { 'relay' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_dhcrelay: failed to create relay: #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client = api_client
    uuid   = @property_hash[:uuid]

    result = client.post("dhcrelay/settings/del_relay/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_dhcrelay: failed to delete relay (uuid: #{uuid}): #{result.inspect}"
    end

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

    client = api_client
    device = @property_hash[:device] || resource[:device]
    uuid   = @property_hash[:uuid]
    config = @pending_config.dup
    config = PuppetX::Opn::HaproxyUuidResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("dhcrelay/settings/set_relay/#{uuid}", { 'relay' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_dhcrelay: failed to update relay (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::DhcrelayReconfigure.mark(device, client)
  end
end
