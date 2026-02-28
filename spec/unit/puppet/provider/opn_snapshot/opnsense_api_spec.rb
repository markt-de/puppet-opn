# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_snapshot/opnsense_api'

describe Puppet::Type.type(:opn_snapshot).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_snapshot) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches snapshots from the API' do
      allow(client).to receive(:get).with('core/snapshots/search')
                                    .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'pre-upgrade', 'active' => '-' }] })
      allow(client).to receive(:get).with('core/snapshots/get/aaa')
                                    .and_return({ 'note' => 'test' })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('pre-upgrade@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:active]).to eq(:false)
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('note' => 'test')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).not_to have_key('uuid')
    end

    it 'sets active to :true when active is not a dash' do
      allow(client).to receive(:get).with('core/snapshots/search')
                                    .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'stable', 'active' => 'Yes' }] })
      allow(client).to receive(:get).with('core/snapshots/get/aaa')
                                    .and_return({ 'note' => 'stable config' })
      instances = described_class.instances
      expect(instances[0].instance_variable_get(:@property_hash)[:active]).to eq(:true)
    end

    it 'skips rows with empty name' do
      allow(client).to receive(:get).with('core/snapshots/search')
                                    .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '', 'active' => '-' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:get).with('core/snapshots/search')
                                    .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:get).with('core/snapshots/search')
                                    .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'pre-upgrade', 'active' => '-' }] })
      allow(client).to receive(:get).with('core/snapshots/get/aaa')
                                    .and_return({ 'note' => 'test' })
      resource = type_class.new(name: 'pre-upgrade@fw01')
      described_class.prefetch({ 'pre-upgrade@fw01' => resource })
      expect(resource.provider.name).to eq('pre-upgrade@fw01')
    end
  end

  describe '#create' do
    it 'calls the add endpoint with flat params' do
      resource = type_class.new(name: 'pre-upgrade@fw01', config: { 'note' => 'test' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'core/snapshots/add',
        hash_including('name' => 'pre-upgrade', 'note' => 'test'),
      ).and_return({ 'status' => 'ok' })
      provider.create
    end

    it 'activates the snapshot when active is true' do
      resource = type_class.new(name: 'pre-upgrade@fw01', active: :true, config: { 'note' => 'test' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('core/snapshots/add', anything)
                                     .and_return({ 'status' => 'ok' })
      allow(client).to receive(:get).with('core/snapshots/search')
                                    .and_return({ 'rows' => [{ 'uuid' => 'new-uuid', 'name' => 'pre-upgrade', 'active' => '-' }] })
      expect(client).to receive(:post).with('core/snapshots/activate/new-uuid', {})
                                      .and_return({ 'status' => 'ok' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'pre-upgrade@fw01', config: { 'note' => 'test' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'status' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the del endpoint' do
      resource = type_class.new(name: 'pre-upgrade@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
        active: :false,
                                     })
      expect(client).to receive(:post).with('core/snapshots/del/aaa', {})
                                      .and_return({ 'status' => 'ok' })
      provider.destroy
    end

    it 'raises when snapshot is active' do
      resource = type_class.new(name: 'pre-upgrade@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
        active: :true,
                                     })
      expect { provider.destroy }.to raise_error(Puppet::Error, %r{cannot delete active snapshot})
    end
  end

  describe '#flush' do
    it 'calls the set endpoint with flat params when config has changed' do
      resource = type_class.new(name: 'pre-upgrade@fw01', config: { 'note' => 'updated' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
        config: { 'name' => 'pre-upgrade', 'note' => 'test' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'note' => 'updated' })
      expect(client).to receive(:post).with(
        'core/snapshots/set/aaa',
        hash_including('name' => 'pre-upgrade', 'note' => 'updated'),
      ).and_return({ 'status' => 'ok' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'pre-upgrade@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'pre-upgrade@fw01', config: { 'note' => 'updated' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
                                     })
      provider.instance_variable_set(:@pending_config, { 'note' => 'updated' })
      allow(client).to receive(:post).and_return({ 'status' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end

  describe '#active=' do
    it 'calls the activate endpoint when set to true' do
      resource = type_class.new(name: 'pre-upgrade@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
        active: :false,
                                     })
      expect(client).to receive(:post).with('core/snapshots/activate/aaa', {})
                                      .and_return({ 'status' => 'ok' })
      provider.active = :true
    end

    it 'warns when trying to deactivate' do
      resource = type_class.new(name: 'pre-upgrade@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'pre-upgrade@fw01', device: 'fw01', uuid: 'aaa',
        active: :true,
                                     })
      expect(Puppet).to receive(:warning).with(%r{cannot deactivate})
      provider.active = :false
    end
  end
end
