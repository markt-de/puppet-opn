# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

type_class = Puppet::Type.type(:opn_haproxy_action)
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
        'linkedAcls', 'use_backend', 'use_server',
        'mapfile', 'map_data_use_backend_file',
        'map_data_use_backend_default', 'map_use_backend_file',
        'map_use_backend_default'
      )
    end
  end

  describe '.instances' do
    it 'returns an empty array when no actions exist' do
      allow(client).to receive(:post).with('haproxy/settings/search_actions', {})
                                     .and_return({ 'rows' => [] })
      expect(described_class.instances).to eq([])
    end

    it 'translates UUIDs to names' do
      allow(client).to receive(:post).with('haproxy/settings/search_actions', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'redirect_https', 'use_backend' => 'uuid1' }] })
      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'name' => 'redirect_https', 'use_backend' => 'web_backend' })

      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances.first.get(:name)).to eq('redirect_https@fw01')
      expect(instances.first.get(:config)).to eq({ 'name' => 'redirect_https', 'use_backend' => 'web_backend' })
    end

    it 'skips rows with empty names' do
      allow(client).to receive(:post).with('haproxy/settings/search_actions', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '' }] })
      expect(described_class.instances).to eq([])
    end
  end

  describe '.prefetch' do
    it 'matches resources to instances' do
      allow(client).to receive(:post).with('haproxy/settings/search_actions', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'redirect_https', 'type' => 'redirect' }] })
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'name' => 'redirect_https', 'type' => 'redirect' })

      resource = type_class.new(name: 'redirect_https@fw01', config: { 'type' => 'redirect' })
      resources = { 'redirect_https@fw01' => resource }
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
      provider = described_class.new(ensure: :present, name: 'redirect_https@fw01')
      expect(provider.exists?).to be true
    end

    it 'returns false when ensure is absent' do
      provider = described_class.new(ensure: :absent, name: 'redirect_https@fw01')
      expect(provider.exists?).to be false
    end
  end

  describe '#create' do
    it 'translates names to UUIDs before API call' do
      resource = type_class.new(name: 'redirect_https@fw01', config: { 'type' => 'redirect' })
      provider = described_class.new(resource)
      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'redirect_https', 'type' => 'redirect' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      allow(client).to receive(:post).with('haproxy/settings/add_action', { 'action' => { 'name' => 'redirect_https', 'type' => 'redirect' } })
                                     .and_return({ 'result' => 'saved' })

      provider.create
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'redirect_https@fw01', config: { 'type' => 'redirect' })
      provider = described_class.new(resource)
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'redirect_https', 'type' => 'redirect' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'deletes the action and marks reconfigure' do
      resource = type_class.new(name: 'redirect_https@fw01')
      provider = described_class.new(
        ensure: :present,
        name: 'redirect_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      expect(client).to receive(:post).with('haproxy/settings/del_action/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })

      provider.destroy
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'redirect_https@fw01')
      provider = described_class.new(
        ensure: :present,
        name: 'redirect_https@fw01',
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
    it 'translates names to UUIDs and updates the action' do
      resource = type_class.new(name: 'redirect_https@fw01', config: { 'type' => 'use_backend' })
      provider = described_class.new(
        ensure: :present,
        name: 'redirect_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'redirect_https', 'type' => 'redirect' },
      )
      provider.resource = resource
      provider.config = { 'type' => 'use_backend' }

      expect(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'redirect_https', 'type' => 'use_backend' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)
      allow(client).to receive(:post)
        .with('haproxy/settings/set_action/aaa-bbb', { 'action' => { 'name' => 'redirect_https', 'type' => 'use_backend' } })
        .and_return({ 'result' => 'saved' })

      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'redirect_https@fw01', config: { 'type' => 'redirect' })
      provider = described_class.new(
        ensure: :present,
        name: 'redirect_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
      )
      provider.resource = resource

      provider.flush
      # No API call expected
    end

    it 'marks error on failure' do
      resource = type_class.new(name: 'redirect_https@fw01', config: { 'type' => 'use_backend' })
      provider = described_class.new(
        ensure: :present,
        name: 'redirect_https@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'redirect_https', 'type' => 'redirect' },
      )
      provider.resource = resource
      provider.config = { 'type' => 'use_backend' }

      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'name' => 'redirect_https', 'type' => 'use_backend' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark_error).with('fw01')

      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
