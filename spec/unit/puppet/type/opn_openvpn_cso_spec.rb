# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_openvpn_cso) do
  let(:type_name) { :opn_openvpn_cso }
  let(:title) { 'client1@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips common_name during comparison' do
      is_config = { 'common_name' => 'x', 'enabled' => '1' }
      should_config = { 'common_name' => 'z', 'enabled' => '1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'autorequires' do
    it 'autorequires OpenVPN instances' do
      catalog = Puppet::Resource::Catalog.new
      cso = Puppet::Type.type(:opn_openvpn_cso).new(
        name: 'client1@opnsense01',
        config: { 'servers' => 'server1,server2' },
      )
      inst1 = Puppet::Type.type(:opn_openvpn_instance).new(name: 'server1@opnsense01')
      inst2 = Puppet::Type.type(:opn_openvpn_instance).new(name: 'server2@opnsense01')
      catalog.add_resource(cso, inst1, inst2)
      reqs = cso.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_openvpn_instance[server1@opnsense01]')
      expect(req_sources).to include('Opn_openvpn_instance[server2@opnsense01]')
    end
  end
end
