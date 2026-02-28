# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_syslog/opnsense_api'

describe Puppet::Type.type(:opn_syslog).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_syslog) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    described_class.instance_variable_set(:@devices_to_reconfigure, {})
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches syslog destinations from the API' do
      allow(client).to receive(:post).with('syslog/settings/search_destinations', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'description' => 'remote_syslog', 'transport' => 'udp4' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('remote_syslog@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('description' => 'remote_syslog', 'transport' => 'udp4')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).not_to have_key('uuid')
    end

    it 'skips rows with empty description' do
      allow(client).to receive(:post).with('syslog/settings/search_destinations', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'description' => '', 'transport' => 'udp4' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:post).with('syslog/settings/search_destinations', {})
                                     .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:post).with('syslog/settings/search_destinations', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'description' => 'remote_syslog', 'transport' => 'udp4' }] })
      resource = type_class.new(name: 'remote_syslog@fw01')
      described_class.prefetch({ 'remote_syslog@fw01' => resource })
      expect(resource.provider.name).to eq('remote_syslog@fw01')
    end
  end

  describe '#create' do
    it 'calls the add_destination endpoint' do
      resource = type_class.new(name: 'remote_syslog@fw01', config: { 'transport' => 'udp4' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'syslog/settings/add_destination',
        hash_including('destination' => hash_including('description' => 'remote_syslog', 'transport' => 'udp4')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'remote_syslog@fw01', config: { 'transport' => 'udp4' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'remote_syslog@fw01', config: { 'transport' => 'udp4' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('syslog/settings/add_destination', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.create
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '#destroy' do
    it 'calls the del_destination endpoint' do
      resource = type_class.new(name: 'remote_syslog@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('syslog/settings/del_destination/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'remote_syslog@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'remote_syslog@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).with('syslog/settings/del_destination/aaa-bbb', {})
                                     .and_return({ 'result' => 'deleted' })
      provider.destroy
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '#flush' do
    it 'calls the set_destination endpoint when config has changed' do
      resource = type_class.new(name: 'remote_syslog@fw01', config: { 'transport' => 'tcp4' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
        config: { 'description' => 'remote_syslog', 'transport' => 'udp4' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'transport' => 'tcp4' })
      expect(client).to receive(:post).with(
        'syslog/settings/set_destination/aaa-bbb',
        hash_including('destination' => hash_including('description' => 'remote_syslog', 'transport' => 'tcp4')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'remote_syslog@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'remote_syslog@fw01', config: { 'transport' => 'tcp4' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'transport' => 'tcp4' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'remote_syslog@fw01', config: { 'transport' => 'tcp4' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'remote_syslog@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'transport' => 'tcp4' })
      allow(client).to receive(:post).with('syslog/settings/set_destination/aaa-bbb', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.flush
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '.post_resource_eval' do
    it 'calls reconfigure for each device that had changes' do
      described_class.devices_to_reconfigure['fw01'] = client
      expect(client).to receive(:post).with('syslog/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })
      described_class.post_resource_eval
    end

    it 'clears devices_to_reconfigure after reconfigure' do
      described_class.devices_to_reconfigure['fw01'] = client
      allow(client).to receive(:post).with('syslog/service/reconfigure', {})
                                     .and_return({ 'status' => 'ok' })
      described_class.post_resource_eval
      expect(described_class.devices_to_reconfigure).to be_empty
    end

    it 'does nothing when no devices need reconfigure' do
      described_class.post_resource_eval
      # No API calls expected
    end
  end
end
