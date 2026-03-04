# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_gateway/opnsense_api'

describe Puppet::Type.type(:opn_gateway).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_gateway) }
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
    let(:search_row) do
      {
        'uuid' => 'aaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'name' => 'WAN_GW',
        'descr' => 'WAN Gateway',
        'interface' => 'wan',
        'ipprotocol' => 'inet',
        'gateway' => '192.168.1.1',
        'disabled' => false,
        'defaultgw' => false,
        'upstream' => true,
        'fargw' => '0',
        'monitor_disable' => '1',
        'priority' => '255',
        'weight' => '1',
        'virtual' => false,
        'interface_descr' => 'WAN',
        'status' => 'Online',
        'delay' => '1.2ms',
        'stddev' => '0.5ms',
        'loss' => '0.0%',
        'label_class' => 'fa fa-plug text-success',
        'if' => 'em0',
        'attribute' => 0,
      }
    end

    it 'fetches gateways from the API and normalizes config' do
      # Use a proper UUID format so it passes the filter
      row = search_row.merge('uuid' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
      allow(client).to receive(:post).with('routing/settings/searchGateway', {})
                                     .and_return({ 'rows' => [row] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('WAN_GW@opnsense01')

      config = instances[0].instance_variable_get(:@property_hash)[:config]
      # Boolean disabled=false should be normalized to '0'
      expect(config['disabled']).to eq('0')
      # Model defaultgw restored from upstream=true, normalized to '1'
      expect(config['defaultgw']).to eq('1')
      # Enrichment fields must be removed
      expect(config).not_to have_key('uuid')
      expect(config).not_to have_key('virtual')
      expect(config).not_to have_key('upstream')
      expect(config).not_to have_key('interface_descr')
      expect(config).not_to have_key('status')
      expect(config).not_to have_key('delay')
      expect(config).not_to have_key('label_class')
      expect(config).not_to have_key('if')
      expect(config).not_to have_key('attribute')
    end

    it 'skips virtual gateways without real UUID' do
      # Virtual gateways get their name as UUID (not a real UUID format)
      row = search_row.merge('uuid' => 'WAN_DHCP', 'name' => 'WAN_DHCP', 'virtual' => true)
      allow(client).to receive(:post).with('routing/settings/searchGateway', {})
                                     .and_return({ 'rows' => [row] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'skips rows with empty name' do
      row = search_row.merge('uuid' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'name' => '')
      allow(client).to receive(:post).with('routing/settings/searchGateway', {})
                                     .and_return({ 'rows' => [row] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'strips current_* computed fields' do
      row = search_row.merge(
        'uuid' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'current_latencylow' => '200',
        'current_latencyhigh' => '500',
      )
      allow(client).to receive(:post).with('routing/settings/searchGateway', {})
                                     .and_return({ 'rows' => [row] })
      instances = described_class.instances
      config = instances[0].instance_variable_get(:@property_hash)[:config]
      expect(config).not_to have_key('current_latencylow')
      expect(config).not_to have_key('current_latencyhigh')
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      row = {
        'uuid' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'name' => 'WAN_GW', 'interface' => 'wan', 'disabled' => false,
        'upstream' => false, 'defaultgw' => false,
      }
      allow(client).to receive(:post).with('routing/settings/searchGateway', {})
                                     .and_return({ 'rows' => [row] })
      resource = type_class.new(name: 'WAN_GW@opnsense01')
      described_class.prefetch({ 'WAN_GW@opnsense01' => resource })
      expect(resource.provider.name).to eq('WAN_GW@opnsense01')
    end
  end

  describe '#create' do
    it 'calls the addGateway endpoint' do
      resource = type_class.new(name: 'WAN_GW@opnsense01', config: { 'interface' => 'wan', 'gateway' => '192.168.1.1' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'routing/settings/addGateway',
        hash_including('gateway_item' => hash_including('name' => 'WAN_GW', 'interface' => 'wan', 'gateway' => '192.168.1.1')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'WAN_GW@opnsense01', config: { 'interface' => 'wan' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure via ServiceReconfigure' do
      resource = type_class.new(name: 'WAN_GW@opnsense01', config: { 'interface' => 'wan' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('routing/settings/addGateway', anything)
                                     .and_return({ 'result' => 'saved' })
      expect(PuppetX::Opn::ServiceReconfigure[:gateway]).to receive(:mark).with('opnsense01', client)
      provider.create
    end
  end

  describe '#destroy' do
    it 'calls the delGateway endpoint' do
      resource = type_class.new(name: 'WAN_GW@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                                     })
      expect(client).to receive(:post).with('routing/settings/delGateway/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'WAN_GW@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure via ServiceReconfigure' do
      resource = type_class.new(name: 'WAN_GW@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                                     })
      allow(client).to receive(:post).with('routing/settings/delGateway/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', {})
                                     .and_return({ 'result' => 'deleted' })
      expect(PuppetX::Opn::ServiceReconfigure[:gateway]).to receive(:mark).with('opnsense01', client)
      provider.destroy
    end
  end

  describe '#flush' do
    it 'calls the setGateway endpoint when config has changed' do
      resource = type_class.new(name: 'WAN_GW@opnsense01', config: { 'interface' => 'wan', 'gateway' => '192.168.1.2' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        config: { 'name' => 'WAN_GW', 'interface' => 'wan', 'gateway' => '192.168.1.1' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'interface' => 'wan', 'gateway' => '192.168.1.2' })
      expect(client).to receive(:post).with(
        'routing/settings/setGateway/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        hash_including('gateway_item' => hash_including('name' => 'WAN_GW', 'interface' => 'wan', 'gateway' => '192.168.1.2')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'WAN_GW@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'WAN_GW@opnsense01', config: { 'interface' => 'wan' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                                     })
      provider.instance_variable_set(:@pending_config, { 'interface' => 'wan' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure via ServiceReconfigure' do
      resource = type_class.new(name: 'WAN_GW@opnsense01', config: { 'interface' => 'wan' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'WAN_GW@opnsense01',
                                       device: 'opnsense01', uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                                     })
      provider.instance_variable_set(:@pending_config, { 'interface' => 'wan' })
      allow(client).to receive(:post).with('routing/settings/setGateway/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', anything)
                                     .and_return({ 'result' => 'saved' })
      expect(PuppetX::Opn::ServiceReconfigure[:gateway]).to receive(:mark).with('opnsense01', client)
      provider.flush
    end
  end

  describe '.post_resource_eval' do
    it 'delegates to ServiceReconfigure[:gateway].run' do
      expect(PuppetX::Opn::ServiceReconfigure[:gateway]).to receive(:run)
      described_class.post_resource_eval
    end
  end
end
