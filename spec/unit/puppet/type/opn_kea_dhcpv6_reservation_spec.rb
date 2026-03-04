# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_kea_dhcpv6_reservation) do
  let(:type_name) { :opn_kea_dhcpv6_reservation }
  let(:title) { 'Mail Server@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'Mail Server', 'subnet' => 'fd00::/64' }
      should_config = { 'description' => 'different', 'subnet' => 'fd00::/64' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'autorequires' do
    it 'autorequires the DHCPv6 subnet' do
      catalog = Puppet::Resource::Catalog.new
      reservation = Puppet::Type.type(:opn_kea_dhcpv6_reservation).new(
        name: 'Mail Server@opnsense01',
        config: { 'subnet' => 'fd00::/64' },
      )
      subnet = Puppet::Type.type(:opn_kea_dhcpv6_subnet).new(name: 'fd00::/64@opnsense01')
      catalog.add_resource(reservation, subnet)
      reqs = reservation.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_kea_dhcpv6_subnet[fd00::/64@opnsense01]')
    end
  end
end
