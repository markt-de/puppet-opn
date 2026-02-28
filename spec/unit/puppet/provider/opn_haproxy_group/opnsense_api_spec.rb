# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

type_class = Puppet::Type.type(:opn_haproxy_group)
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
      expect(fields.keys).to include('members')
    end
  end

  describe '.instances' do
    it 'returns an empty array when no groups exist' do
      allow(client).to receive(:post).with('haproxy/settings/search_groups', {})
                                     .and_return({ 'rows' => [] })
      expect(described_class.instances).to eq([])
    end

    it 'translates UUIDs to names' do
      allow(client).to receive(:post).with('haproxy/settings/search_groups', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'admins', 'members' => 'uuid1,uuid2' }] })
      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'name' => 'admins', 'members' => 'user1,user2' })

      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances.first.get(:name)).to eq('admins@fw01')
      expect(instances.first.get(:config)).to eq({ 'name' => 'admins', 'members' => 'user1,user2' })
    end

    it 'skips rows with empty names' do
      allow(client).to receive(:post).with('haproxy/settings/search_groups', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '' }] })
      expect(described_class.instances).to eq([])
    end
  end

  describe '.prefetch' do
    it 'matches resources to instances' do
      allow(client).to receive(:post).with('haproxy/settings/search_groups', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'admins', 'description' => 'Admin group' }] })
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'name' => 'admins', 'description' => 'Admin group' })

      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Admin group' })
      resources = { 'admins@fw01' => resource }
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
      provider = described_class.new(ensure: :present, name: 'admins@fw01')
      expect(provider.exists?).to be true
    end

    it 'returns false when ensure is absent' do
      provider = described_class.new(ensure: :absent, name: 'admins@fw01')
      expect(provider.exists?).to be false
    end
  end

  describe '#create' do
    it 'translates names to UUIDs before API call' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Admin group' })
      provider = described_class.new(resource)
      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'admins', 'description' => 'Admin group' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      allow(client).to receive(:post).with('haproxy/settings/add_group', { 'group' => { 'name' => 'admins', 'description' => 'Admin group' } })
                                     .and_return({ 'result' => 'saved' })

      provider.create
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Admin group' })
      provider = described_class.new(resource)
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'admins', 'description' => 'Admin group' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'deletes the group and marks reconfigure' do
      resource = type_class.new(name: 'admins@fw01')
      provider = described_class.new(
        ensure: :present,
        name: 'admins@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      expect(client).to receive(:post).with('haproxy/settings/del_group/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })

      provider.destroy
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'admins@fw01')
      provider = described_class.new(
        ensure: :present,
        name: 'admins@fw01',
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
    it 'translates names to UUIDs and updates the group' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Updated' })
      provider = described_class.new(
        ensure: :present,
        name: 'admins@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'admins', 'description' => 'Original' },
      )
      provider.resource = resource
      provider.config = { 'description' => 'Updated' }

      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'admins', 'description' => 'Updated' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      allow(client).to receive(:post)
        .with('haproxy/settings/set_group/aaa-bbb', { 'group' => { 'name' => 'admins', 'description' => 'Updated' } })
        .and_return({ 'result' => 'saved' })

      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Admin group' })
      provider = described_class.new(
        ensure: :present,
        name: 'admins@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource

      provider.flush
      # No API call expected
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Updated' })
      provider = described_class.new(
        ensure: :present,
        name: 'admins@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'admins', 'description' => 'Original' },
      )
      provider.resource = resource
      provider.config = { 'description' => 'Updated' }

      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'admins', 'description' => 'Updated' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
