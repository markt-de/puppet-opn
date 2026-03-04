# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_kea_dhcpv6_pd_pool) do
  let(:type_name) { :opn_kea_dhcpv6_pd_pool }
  let(:title) { 'Customer PD Pool@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'Customer PD Pool', 'prefix' => 'fd00:1::/48' }
      should_config = { 'description' => 'different', 'prefix' => 'fd00:1::/48' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'autorequires' do
    it 'autorequires the DHCPv6 subnet' do
      catalog = Puppet::Resource::Catalog.new
      pd_pool = Puppet::Type.type(:opn_kea_dhcpv6_pd_pool).new(
        name: 'Customer PD Pool@opnsense01',
        config: { 'subnet' => 'fd00::/64' },
      )
      subnet = Puppet::Type.type(:opn_kea_dhcpv6_subnet).new(name: 'fd00::/64@opnsense01')
      catalog.add_resource(pd_pool, subnet)
      reqs = pd_pool.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_kea_dhcpv6_subnet[fd00::/64@opnsense01]')
    end
  end
end
