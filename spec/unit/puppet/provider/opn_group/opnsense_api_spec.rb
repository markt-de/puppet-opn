# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_group/opnsense_api'

describe Puppet::Type.type(:opn_group).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_group) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches groups from the API' do
      allow(client).to receive(:post).with('auth/group/search', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'admins', 'description' => 'Admin group' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('admins@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('name' => 'admins', 'description' => 'Admin group')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).not_to have_key('uuid')
    end

    it 'skips rows with empty name' do
      allow(client).to receive(:post).with('auth/group/search', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '', 'description' => '' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:post).with('auth/group/search', {})
                                     .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:post).with('auth/group/search', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'admins', 'description' => 'Admin group' }] })
      resource = type_class.new(name: 'admins@fw01')
      described_class.prefetch({ 'admins@fw01' => resource })
      expect(resource.provider.name).to eq('admins@fw01')
    end
  end

  describe '#create' do
    it 'calls the add endpoint' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Admin group' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'auth/group/add',
        hash_including('group' => hash_including('name' => 'admins', 'description' => 'Admin group')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Admin group' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the del endpoint' do
      resource = type_class.new(name: 'admins@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'admins@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('auth/group/del/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'admins@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'admins@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'calls the set endpoint when config has changed' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Super admins' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'admins@fw01', device: 'fw01', uuid: 'aaa-bbb',
        config: { 'name' => 'admins', 'description' => 'Admin group' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'description' => 'Super admins' })
      expect(client).to receive(:post).with(
        'auth/group/set/aaa-bbb',
        hash_including('group' => hash_including('name' => 'admins', 'description' => 'Super admins')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'admins@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'admins@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'admins@fw01', config: { 'description' => 'Super admins' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'admins@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'description' => 'Super admins' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
