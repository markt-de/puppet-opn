# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_haproxy_backend) do
  let(:type_name) { :opn_haproxy_backend }
  let(:title) { 'web_backend@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name key during comparison' do
      is_config = { 'name' => 'different', 'expression' => 'ssl_fc' }
      should_config = { 'name' => 'original', 'expression' => 'ssl_fc' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'autorequires' do
    it 'autorequires linked servers' do
      catalog = Puppet::Resource::Catalog.new
      backend = Puppet::Type.type(:opn_haproxy_backend).new(
        name: 'web_backend@fw01',
        config: { 'linkedServers' => 'web01,web02' },
      )
      server1 = Puppet::Type.type(:opn_haproxy_server).new(name: 'web01@fw01')
      server2 = Puppet::Type.type(:opn_haproxy_server).new(name: 'web02@fw01')
      catalog.add_resource(backend, server1, server2)
      reqs = backend.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_haproxy_server[web01@fw01]')
      expect(req_sources).to include('Opn_haproxy_server[web02@fw01]')
    end

    it 'autorequires linked actions' do
      catalog = Puppet::Resource::Catalog.new
      backend = Puppet::Type.type(:opn_haproxy_backend).new(
        name: 'web_backend@fw01',
        config: { 'linkedActions' => 'action01,action02' },
      )
      action1 = Puppet::Type.type(:opn_haproxy_action).new(name: 'action01@fw01')
      action2 = Puppet::Type.type(:opn_haproxy_action).new(name: 'action02@fw01')
      catalog.add_resource(backend, action1, action2)
      reqs = backend.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_haproxy_action[action01@fw01]')
      expect(req_sources).to include('Opn_haproxy_action[action02@fw01]')
    end

    it 'autorequires linked errorfiles' do
      catalog = Puppet::Resource::Catalog.new
      backend = Puppet::Type.type(:opn_haproxy_backend).new(
        name: 'web_backend@fw01',
        config: { 'linkedErrorfiles' => 'err503,err404' },
      )
      err1 = Puppet::Type.type(:opn_haproxy_errorfile).new(name: 'err503@fw01')
      err2 = Puppet::Type.type(:opn_haproxy_errorfile).new(name: 'err404@fw01')
      catalog.add_resource(backend, err1, err2)
      reqs = backend.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_haproxy_errorfile[err503@fw01]')
      expect(req_sources).to include('Opn_haproxy_errorfile[err404@fw01]')
    end

    it 'autorequires basic auth users' do
      catalog = Puppet::Resource::Catalog.new
      backend = Puppet::Type.type(:opn_haproxy_backend).new(
        name: 'web_backend@fw01',
        config: { 'basicAuthUsers' => 'admin,viewer' },
      )
      user1 = Puppet::Type.type(:opn_haproxy_user).new(name: 'admin@fw01')
      user2 = Puppet::Type.type(:opn_haproxy_user).new(name: 'viewer@fw01')
      catalog.add_resource(backend, user1, user2)
      reqs = backend.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_haproxy_user[admin@fw01]')
      expect(req_sources).to include('Opn_haproxy_user[viewer@fw01]')
    end

    it 'autorequires basic auth groups' do
      catalog = Puppet::Resource::Catalog.new
      backend = Puppet::Type.type(:opn_haproxy_backend).new(
        name: 'web_backend@fw01',
        config: { 'basicAuthGroups' => 'admins,readers' },
      )
      group1 = Puppet::Type.type(:opn_haproxy_group).new(name: 'admins@fw01')
      group2 = Puppet::Type.type(:opn_haproxy_group).new(name: 'readers@fw01')
      catalog.add_resource(backend, group1, group2)
      reqs = backend.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_haproxy_group[admins@fw01]')
      expect(req_sources).to include('Opn_haproxy_group[readers@fw01]')
    end
  end
end
