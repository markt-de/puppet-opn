# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_ipsec_local) do
  let(:type_name) { :opn_ipsec_local }
  let(:title) { 'local-auth@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'auth' => 'pubkey' }
      should_config = { 'description' => 'z', 'auth' => 'pubkey' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'autorequires' do
    it 'autorequires the IPsec connection' do
      catalog = Puppet::Resource::Catalog.new
      local = Puppet::Type.type(:opn_ipsec_local).new(
        name: 'local-auth@opnsense01',
        config: { 'connection' => 'site-to-site' },
      )
      connection = Puppet::Type.type(:opn_ipsec_connection).new(name: 'site-to-site@opnsense01')
      catalog.add_resource(local, connection)
      reqs = local.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_ipsec_connection[site-to-site@opnsense01]')
    end

    it 'autorequires key pairs' do
      catalog = Puppet::Resource::Catalog.new
      local = Puppet::Type.type(:opn_ipsec_local).new(
        name: 'local-auth@opnsense01',
        config: { 'pubkeys' => 'key1,key2' },
      )
      kp1 = Puppet::Type.type(:opn_ipsec_keypair).new(name: 'key1@opnsense01')
      kp2 = Puppet::Type.type(:opn_ipsec_keypair).new(name: 'key2@opnsense01')
      catalog.add_resource(local, kp1, kp2)
      reqs = local.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_ipsec_keypair[key1@opnsense01]')
      expect(req_sources).to include('Opn_ipsec_keypair[key2@opnsense01]')
    end
  end
end
