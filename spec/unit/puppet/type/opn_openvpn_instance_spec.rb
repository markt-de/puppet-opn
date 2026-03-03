# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_openvpn_instance) do
  let(:type_name) { :opn_openvpn_instance }
  let(:title) { 'roadwarrior-server@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'role' => 'server' }
      should_config = { 'description' => 'z', 'role' => 'server' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips volatile fields during comparison' do
      is_config = { 'role' => 'server', 'vpnid' => '42' }
      should_config = { 'role' => 'server', 'vpnid' => '0' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips password during comparison' do
      is_config = { 'role' => 'server', 'password' => 'stored-hash' }
      should_config = { 'role' => 'server', 'password' => 'new-password' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'role' => 'server' }
      should_config = { 'role' => 'client' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end

  describe 'autorequires' do
    it 'autorequires the static key' do
      catalog = Puppet::Resource::Catalog.new
      instance = Puppet::Type.type(:opn_openvpn_instance).new(
        name: 'roadwarrior-server@opnsense01',
        config: { 'tls_key' => 'my-tls-auth-key' },
      )
      sk = Puppet::Type.type(:opn_openvpn_statickey).new(name: 'my-tls-auth-key@opnsense01')
      catalog.add_resource(instance, sk)
      reqs = instance.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_openvpn_statickey[my-tls-auth-key@opnsense01]')
    end
  end
end
