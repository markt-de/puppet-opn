# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_kea_dhcpv4_reservation) do
  let(:type_name) { :opn_kea_dhcpv4_reservation }
  let(:title) { 'Web Server@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'returns true when should is a subset of is (deep match)' do
      is_config = { 'description' => 'Web Server', 'subnet' => '192.168.1.0/24', 'hw_address' => 'AA:BB:CC:DD:EE:FF' }
      should_config = { 'subnet' => '192.168.1.0/24', 'hw_address' => 'AA:BB:CC:DD:EE:FF' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'autorequires' do
    it 'autorequires the DHCPv4 subnet' do
      catalog = Puppet::Resource::Catalog.new
      reservation = Puppet::Type.type(:opn_kea_dhcpv4_reservation).new(
        name: 'Web Server@opnsense01',
        config: { 'subnet' => '192.168.1.0/24' },
      )
      subnet = Puppet::Type.type(:opn_kea_dhcpv4_subnet).new(name: '192.168.1.0/24@opnsense01')
      catalog.add_resource(reservation, subnet)
      reqs = reservation.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_kea_dhcpv4_subnet[192.168.1.0/24@opnsense01]')
    end
  end
end
