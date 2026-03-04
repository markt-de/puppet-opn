# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_kea_dhcpv6/opnsense_api'

describe Puppet::Type.type(:opn_kea_dhcpv6).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_kea_dhcpv6) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['opnsense01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('opnsense01').and_return(client)
    PuppetX::Opn::ServiceReconfigure.reset!
    load 'puppet_x/opn/service_reconfigure_registry.rb'
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches settings via GET' do
      allow(client).to receive(:get).with('kea/dhcpv6/get')
                                    .and_return({ 'dhcpv6' => { 'general' => { 'enabled' => '1' }, 'lexpire' => {}, 'ha' => {} } })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('opnsense01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('general' => hash_including('enabled' => '1'))
    end
  end

  describe '#create' do
    it 'saves settings via POST' do
      config = { 'general' => { 'enabled' => '1' } }
      resource = type_class.new(name: 'opnsense01', config: config)
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'kea/dhcpv6/set',
        hash_including('dhcpv6' => config),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'opnsense01', config: { 'general' => { 'enabled' => '1' } })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'saves empty settings and marks reconfigure' do
      resource = type_class.new(name: 'opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, { ensure: :present, name: 'opnsense01' })
      allow(client).to receive(:post).with('kea/dhcpv6/set', anything)
                                     .and_return({ 'result' => 'saved' })
      expect(PuppetX::Opn::ServiceReconfigure[:kea]).to receive(:mark).with('opnsense01', client)
      provider.destroy
    end
  end

  describe '#flush' do
    it 'saves pending config via POST' do
      config = { 'general' => { 'enabled' => '0' } }
      resource = type_class.new(name: 'opnsense01', config: config)
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, { ensure: :present, name: 'opnsense01' })
      provider.instance_variable_set(:@pending_config, config)
      expect(client).to receive(:post).with(
        'kea/dhcpv6/set',
        hash_including('dhcpv6' => config),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, { ensure: :present, name: 'opnsense01' })
      provider.flush
    end
  end

  describe '.post_resource_eval' do
    it 'delegates to ServiceReconfigure[:kea].run' do
      expect(PuppetX::Opn::ServiceReconfigure[:kea]).to receive(:run)
      described_class.post_resource_eval
    end
  end
end
