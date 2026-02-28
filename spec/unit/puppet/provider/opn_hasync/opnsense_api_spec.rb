# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_hasync/opnsense_api'

describe Puppet::Type.type(:opn_hasync).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_hasync) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    described_class.instance_variable_set(:@devices_to_reconfigure, {})
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches settings via GET' do
      allow(client).to receive(:get).with('core/hasync/get')
                                    .and_return({ 'hasync' => { 'pfsyncenabled' => '1' } })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('pfsyncenabled' => '1')
    end
  end

  describe '#create' do
    it 'saves settings via POST' do
      resource = type_class.new(name: 'fw01', config: { 'pfsyncenabled' => '1' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'core/hasync/set',
        hash_including('hasync' => { 'pfsyncenabled' => '1' }),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'fw01', config: { 'pfsyncenabled' => '1' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('core/hasync/set', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.create
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'fw01', config: { 'pfsyncenabled' => '1' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'saves empty settings and marks reconfigure' do
      resource = type_class.new(name: 'fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fw01', config: { 'pfsyncenabled' => '1' },
                                     })
      allow(client).to receive(:post).with('core/hasync/set', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.destroy
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '#flush' do
    it 'saves pending config via POST' do
      resource = type_class.new(name: 'fw01', config: { 'pfsyncenabled' => '0' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fw01', config: { 'pfsyncenabled' => '1' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'pfsyncenabled' => '0' })
      expect(client).to receive(:post).with(
        'core/hasync/set',
        hash_including('hasync' => { 'pfsyncenabled' => '0' }),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fw01',
                                     })
      provider.flush
      # No API call expected
    end
  end

  describe '.post_resource_eval' do
    it 'calls reconfigure for each device that had changes' do
      described_class.devices_to_reconfigure['fw01'] = client
      expect(client).to receive(:post).with('core/hasync/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })
      described_class.post_resource_eval
    end

    it 'clears devices_to_reconfigure after run' do
      described_class.devices_to_reconfigure['fw01'] = client
      allow(client).to receive(:post).with('core/hasync/reconfigure', {})
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
