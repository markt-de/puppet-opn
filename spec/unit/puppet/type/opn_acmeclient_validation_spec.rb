# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_acmeclient_validation) do
  let(:type_name) { :opn_acmeclient_validation }
  let(:title) { 'http-01@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name during comparison' do
      is_config = { 'name' => 'different', 'method' => 'http01' }
      should_config = { 'name' => 'original', 'method' => 'http01' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'method' => 'http01' }
      should_config = { 'method' => 'dns01' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end

  describe 'autorequires' do
    it 'autorequires HAProxy frontends' do
      catalog = Puppet::Resource::Catalog.new
      validation = Puppet::Type.type(:opn_acmeclient_validation).new(
        name: 'http-01@fw01',
        config: { 'http_haproxyFrontends' => 'https_in,http_in' },
      )
      fe1 = Puppet::Type.type(:opn_haproxy_frontend).new(name: 'https_in@fw01')
      fe2 = Puppet::Type.type(:opn_haproxy_frontend).new(name: 'http_in@fw01')
      catalog.add_resource(validation, fe1, fe2)
      reqs = validation.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_haproxy_frontend[https_in@fw01]')
      expect(req_sources).to include('Opn_haproxy_frontend[http_in@fw01]')
    end
  end
end
