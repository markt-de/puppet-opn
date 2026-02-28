# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

type_class = Puppet::Type.type(:opn_haproxy_acl)
provider_class = type_class.provider(:opnsense_api)

RSpec.describe provider_class do
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    PuppetX::Opn::HaproxyReconfigure.instance_variable_set(:@devices_to_reconfigure, {})
    PuppetX::Opn::HaproxyReconfigure.instance_variable_set(:@devices_with_errors, {})
    PuppetX::Opn::HaproxyUuidResolver.instance_variable_set(:@cache, {})
  end

  describe '.relation_fields' do
    it 'is defined and contains expected keys' do
      fields = described_class.relation_fields
      expect(fields).to be_a(Hash)
      expect(fields.keys).to include(
        'linkedResolver', 'unix_socket', 'linkedAcls',
        'use_backend', 'use_server', 'nbsrv_backend',
        'queryBackend', 'allowedUsers', 'allowedGroups',
        'mapfile', 'map_data_use_backend_file',
        'map_data_use_backend_default', 'map_use_backend_file',
        'map_use_backend_default', 'linkedActions'
      )
    end
  end

  describe '.instances' do
    it 'returns an empty array when no ACLs exist' do
      allow(client).to receive(:post).with('haproxy/settings/search_acls', {})
                                     .and_return({ 'rows' => [] })
      expect(described_class.instances).to eq([])
    end

    it 'translates UUIDs to names' do
      allow(client).to receive(:post).with('haproxy/settings/search_acls', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'is_https', 'use_backend' => 'uuid1' }] })
      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'name' => 'is_https', 'use_backend' => 'web_backend' })

      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances.first.get(:name)).to eq('is_https@fw01')
      expect(instances.first.get(:config)).to eq({ 'name' => 'is_https', 'use_backend' => 'web_backend' })
    end

    it 'skips rows with empty names' do
      allow(client).to receive(:post).with('haproxy/settings/search_acls', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '' }] })
      expect(described_class.instances).to eq([])
    end
  end

  describe '.prefetch' do
    it 'matches resources to instances' do
      allow(client).to receive(:post).with('haproxy/settings/search_acls', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'is_https', 'expression' => 'ssl_fc' }] })
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'name' => 'is_https', 'expression' => 'ssl_fc' })

      resource = type_class.new(name: 'is_https@fw01', config: { 'expression' => 'ssl_fc' })
      resources = { 'is_https@fw01' => resource }
      described_class.prefetch(resources)
      expect(resource.provider).not_to be_nil
      expect(resource.provider.get(:uuid)).to eq('aaa')
    end
  end

  describe '.post_resource_eval' do
    it 'delegates to HaproxyReconfigure.run' do
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:run)
      described_class.post_resource_eval
    end
  end

  describe '#exists?' do
    it 'returns true when ensure is present' do
      provider = described_class.new(ensure: :present, name: 'is_https@fw01')
      expect(provider.exists?).to be true
    end

    it 'returns false when ensure is absent' do
      provider = described_class.new(ensure: :absent, name: 'is_https@fw01')
      expect(provider.exists?).to be false
    end
  end

  describe '#create' do
    it 'translates names to UUIDs before API call' do
      resource = type_class.new(name: 'is_https@fw01', config: { 'expression' => 'ssl_fc' })
      provider = described_class.new(resource)
      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'is_https', 'expression' => 'ssl_fc' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      allow(client).to receive(:post).with('haproxy/settings/add_acl', { 'acl' => { 'name' => 'is_https', 'expression' => 'ssl_fc' } })
                                     .and_return({ 'result' => 'saved' })

      provider.create
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'is_https@fw01', config: { 'expression' => 'ssl_fc' })
      provider = described_class.new(resource)
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'is_https', 'expression' => 'ssl_fc' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'deletes the ACL and marks reconfigure' do
      resource = type_class.new(name: 'is_https@fw01')
      provider = described_class.new(
        ensure: :present,
        name: 'is_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      expect(client).to receive(:post).with('haproxy/settings/del_acl/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })

      provider.destroy
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'is_https@fw01')
      provider = described_class.new(
        ensure: :present,
        name: 'is_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.destroy }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'translates names to UUIDs and updates the ACL' do
      resource = type_class.new(name: 'is_https@fw01', config: { 'expression' => 'hdr(host)' })
      provider = described_class.new(
        ensure: :present,
        name: 'is_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'is_https', 'expression' => 'ssl_fc' },
      )
      provider.resource = resource
      provider.config = { 'expression' => 'hdr(host)' }

      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'is_https', 'expression' => 'hdr(host)' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      allow(client).to receive(:post)
        .with('haproxy/settings/set_acl/aaa-bbb', { 'acl' => { 'name' => 'is_https', 'expression' => 'hdr(host)' } })
        .and_return({ 'result' => 'saved' })

      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'is_https@fw01', config: { 'expression' => 'ssl_fc' })
      provider = described_class.new(
        ensure: :present,
        name: 'is_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource

      provider.flush
      # No API call expected
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'is_https@fw01', config: { 'expression' => 'hdr(host)' })
      provider = described_class.new(
        ensure: :present,
        name: 'is_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'is_https', 'expression' => 'ssl_fc' },
      )
      provider.resource = resource
      provider.config = { 'expression' => 'hdr(host)' }

      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'is_https', 'expression' => 'hdr(host)' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
