# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_kea_dhcpv4_reservation).provide(:opnsense_api) do
  desc 'Manages OPNsense KEA DHCPv4 reservations via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # The subnet field is a ModelRelationField referencing DHCPv4 subnets.
  # IdResolver translates between UUIDs and subnet CIDRs.
  def self.relation_fields
    {
      'subnet' => { endpoint: 'kea/dhcpv4/searchSubnet', multiple: false, name_field: 'subnet' },
    }.freeze
  end

  # Delegates reconfigure to ServiceReconfigure after all opn_kea_dhcpv4_reservation
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:kea].run
  end

  # Uses search+get pattern: searchReservation returns limited columns,
  # getReservation/{uuid} returns the full configuration including option_data.
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('kea/dhcpv4/searchReservation', {})
      rows     = response['rows'] || []

      rows.each do |row|
        uuid = row['uuid']
        # Fetch full reservation details (option_data, etc.)
        detail    = client.get("kea/dhcpv4/getReservation/#{uuid}")
        item_data = normalize_config(detail['reservation'] || {})

        # Description is the identifier
        item_name = item_data['description'].to_s
        next if item_name.empty?

        # Translate subnet UUID to CIDR for display in Puppet
        item_data = PuppetX::Opn::IdResolver.translate_to_names(
          client, device_name, relation_fields, item_data
        )

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   uuid,
          config: item_data.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_kea_dhcpv4_reservation: failed to fetch from '#{device_name}': #{e.message}")
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

    result = client.post('kea/dhcpv4/addReservation', { 'reservation' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_kea_dhcpv4_reservation: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("kea/dhcpv4/delReservation/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_kea_dhcpv4_reservation: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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

    result = client.post("kea/dhcpv4/setReservation/#{uuid}", { 'reservation' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_kea_dhcpv4_reservation: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
