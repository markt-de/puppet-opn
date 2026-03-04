# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_kea_dhcpv6_subnet/opnsense_api'

describe Puppet::Type.type(:opn_kea_dhcpv6_subnet).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_kea_dhcpv6_subnet) }
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
    it 'fetches subnets via search+get pattern' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchSubnet', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'subnet' => 'fd00::/64' }] })
      allow(client).to receive(:get).with('kea/dhcpv6/getSubnet/aaa-bbb')
                                    .and_return({ 'subnet6' => { 'subnet' => 'fd00::/64', 'description' => 'LAN v6' } })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('fd00::/64@opnsense01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('subnet' => 'fd00::/64')
    end

    it 'skips rows with empty subnet' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchSubnet', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'subnet' => '' }] })
      allow(client).to receive(:get).with('kea/dhcpv6/getSubnet/aaa')
                                    .and_return({ 'subnet6' => { 'subnet' => '' } })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '#create' do
    it 'calls the addSubnet endpoint with subnet CIDR injected' do
      resource = type_class.new(name: 'fd00::/64@opnsense01', config: { 'description' => 'LAN v6' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'kea/dhcpv6/addSubnet',
        hash_including('subnet6' => hash_including('subnet' => 'fd00::/64', 'description' => 'LAN v6')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'fd00::/64@opnsense01', config: { 'description' => 'LAN v6' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the delSubnet endpoint' do
      resource = type_class.new(name: 'fd00::/64@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fd00::/64@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('kea/dhcpv6/delSubnet/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end
  end

  describe '#flush' do
    it 'calls the setSubnet endpoint with subnet CIDR injected' do
      resource = type_class.new(name: 'fd00::/64@opnsense01', config: { 'description' => 'Updated' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fd00::/64@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'description' => 'Updated' })
      expect(client).to receive(:post).with(
        'kea/dhcpv6/setSubnet/aaa-bbb',
        hash_including('subnet6' => hash_including('subnet' => 'fd00::/64', 'description' => 'Updated')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'fd00::/64@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fd00::/64@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
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
