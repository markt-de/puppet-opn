# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_kea_dhcpv6_reservation).provide(:opnsense_api) do
  desc 'Manages OPNsense KEA DHCPv6 reservations via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :kea

  # The subnet field is a ModelRelationField referencing DHCPv6 subnets.
  # IdResolver translates between UUIDs and subnet CIDRs.
  def self.relation_fields
    {
      'subnet' => { endpoint: 'kea/dhcpv6/searchSubnet', multiple: false, name_field: 'subnet' },
    }.freeze
  end

  # Delegates reconfigure to ServiceReconfigure after all opn_kea_dhcpv6_reservation
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:kea].run
  end

  # Uses search-only pattern for instances: searchReservation returns all needed
  # fields. The subnet field in search results is already a display value (CIDR),
  # not a UUID, so no IdResolver translation is needed during prefetch.
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('kea/dhcpv6/searchReservation', {})
      rows     = response['rows'] || []

      rows.each do |row|
        # Description is the identifier
        item_name = row['description'].to_s
        next if item_name.empty?

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: row.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_kea_dhcpv6_reservation: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client    = api_client
    device    = @property_hash[:device] || resource[:device]
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    # Inject the description from the resource title
    config['description'] = item_name
    # Translate subnet CIDR to UUID for the API
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post('kea/dhcpv6/addReservation', { 'reservation' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_kea_dhcpv6_reservation: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("kea/dhcpv6/delReservation/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_kea_dhcpv6_reservation: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  def flush
    return unless @pending_config

    client    = api_client
    device    = @property_hash[:device] || resource[:device]
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    # Inject the description from the resource title
    config['description'] = item_name
    # Translate subnet CIDR to UUID for the API
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("kea/dhcpv6/setReservation/#{uuid}", { 'reservation' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_kea_dhcpv6_reservation: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
