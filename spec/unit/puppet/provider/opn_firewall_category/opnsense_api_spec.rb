# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_firewall_category/opnsense_api'

describe Puppet::Type.type(:opn_firewall_category).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_firewall_category) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    described_class.instance_variable_set(:@devices_to_reconfigure, {}) if described_class.instance_variable_defined?(:@devices_to_reconfigure)
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches categories from the API' do
      allow(client).to receive(:post).with('firewall/category/search_item', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'web_servers', 'color' => 'red' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('web_servers@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('name' => 'web_servers', 'color' => 'red')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).not_to have_key('uuid')
    end

    it 'skips rows with empty name' do
      allow(client).to receive(:post).with('firewall/category/search_item', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '', 'color' => 'red' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:post).with('firewall/category/search_item', {})
                                     .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:post).with('firewall/category/search_item', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'web_servers', 'color' => 'red' }] })
      resource = type_class.new(name: 'web_servers@fw01')
      described_class.prefetch({ 'web_servers@fw01' => resource })
      expect(resource.provider.name).to eq('web_servers@fw01')
    end
  end

  describe '#create' do
    it 'calls the add_item endpoint' do
      resource = type_class.new(name: 'web_servers@fw01', config: { 'color' => 'red' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'firewall/category/add_item',
        hash_including('category' => hash_including('name' => 'web_servers', 'color' => 'red')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'web_servers@fw01', config: { 'color' => 'red' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the del_item endpoint' do
      resource = type_class.new(name: 'web_servers@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'web_servers@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('firewall/category/del_item/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'web_servers@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'web_servers@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'calls the set_item endpoint when config has changed' do
      resource = type_class.new(name: 'web_servers@fw01', config: { 'color' => 'blue' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'web_servers@fw01', device: 'fw01', uuid: 'aaa-bbb',
        config: { 'name' => 'web_servers', 'color' => 'red' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'color' => 'blue' })
      expect(client).to receive(:post).with(
        'firewall/category/set_item/aaa-bbb',
        hash_including('category' => hash_including('name' => 'web_servers', 'color' => 'blue')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'web_servers@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'web_servers@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'web_servers@fw01', config: { 'color' => 'blue' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'web_servers@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'color' => 'blue' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
