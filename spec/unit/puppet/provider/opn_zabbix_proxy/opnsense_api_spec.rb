# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_zabbix_proxy/opnsense_api'

describe Puppet::Type.type(:opn_zabbix_proxy).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_zabbix_proxy) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches settings via GET' do
      allow(client).to receive(:get).with('zabbixproxy/general/get')
                                    .and_return({ 'general' => { 'enabled' => '1' } })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('enabled' => '1')
    end
  end

  describe '#create' do
    it 'saves settings and triggers reconfigure' do
      resource = type_class.new(name: 'fw01', config: { 'enabled' => '1' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'zabbixproxy/general/set',
        hash_including('general' => { 'enabled' => '1' }),
      ).and_return({ 'result' => 'saved' })
      expect(client).to receive(:post).with('zabbixproxy/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'fw01', config: { 'enabled' => '1' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('zabbixproxy/general/set', anything)
                                     .and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'disables and reconfigures' do
      resource = type_class.new(name: 'fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fw01', config: { 'enabled' => '1' },
                                     })
      expect(client).to receive(:post).with(
        'zabbixproxy/general/set',
        hash_including('general' => hash_including('enabled' => '0')),
      ).and_return({ 'result' => 'saved' })
      expect(client).to receive(:post).with('zabbixproxy/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })
      provider.destroy
    end
  end

  describe '#flush' do
    it 'saves pending config and triggers reconfigure' do
      resource = type_class.new(name: 'fw01', config: { 'enabled' => '0' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fw01', config: { 'enabled' => '1' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'enabled' => '0' })
      expect(client).to receive(:post).with(
        'zabbixproxy/general/set',
        hash_including('general' => { 'enabled' => '0' }),
      ).and_return({ 'result' => 'saved' })
      expect(client).to receive(:post).with('zabbixproxy/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })
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
end
