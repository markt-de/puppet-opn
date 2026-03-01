# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_acmeclient_certificate) do
  let(:type_name) { :opn_acmeclient_certificate }
  let(:title) { 'web.example.com@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name during comparison' do
      is_config = { 'name' => 'different', 'altNames' => 'www.example.com' }
      should_config = { 'name' => 'original', 'altNames' => 'www.example.com' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips volatile fields during comparison' do
      is_config = { 'altNames' => 'www.example.com', 'certRefId' => 'abc', 'lastUpdate' => '2024-01-01',
                    'statusCode' => '200', 'statusLastUpdate' => '2024-01-01' }
      should_config = { 'altNames' => 'www.example.com', 'certRefId' => 'xyz', 'lastUpdate' => '',
                        'statusCode' => '0', 'statusLastUpdate' => '' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'altNames' => 'www.example.com' }
      should_config = { 'altNames' => 'api.example.com' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end

  describe 'autorequires' do
    it 'autorequires the ACME account' do
      catalog = Puppet::Resource::Catalog.new
      cert = Puppet::Type.type(:opn_acmeclient_certificate).new(
        name: 'web.example.com@fw01',
        config: { 'account' => 'le-account' },
      )
      account = Puppet::Type.type(:opn_acmeclient_account).new(name: 'le-account@fw01')
      catalog.add_resource(cert, account)
      reqs = cert.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_acmeclient_account[le-account@fw01]')
    end

    it 'autorequires the validation method' do
      catalog = Puppet::Resource::Catalog.new
      cert = Puppet::Type.type(:opn_acmeclient_certificate).new(
        name: 'web.example.com@fw01',
        config: { 'validationMethod' => 'http-01' },
      )
      validation = Puppet::Type.type(:opn_acmeclient_validation).new(name: 'http-01@fw01')
      catalog.add_resource(cert, validation)
      reqs = cert.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_acmeclient_validation[http-01@fw01]')
    end

    it 'autorequires restart actions' do
      catalog = Puppet::Resource::Catalog.new
      cert = Puppet::Type.type(:opn_acmeclient_certificate).new(
        name: 'web.example.com@fw01',
        config: { 'restartActions' => 'restart_haproxy,reload_nginx' },
      )
      action1 = Puppet::Type.type(:opn_acmeclient_action).new(name: 'restart_haproxy@fw01')
      action2 = Puppet::Type.type(:opn_acmeclient_action).new(name: 'reload_nginx@fw01')
      catalog.add_resource(cert, action1, action2)
      reqs = cert.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_acmeclient_action[restart_haproxy@fw01]')
      expect(req_sources).to include('Opn_acmeclient_action[reload_nginx@fw01]')
    end
  end
end
