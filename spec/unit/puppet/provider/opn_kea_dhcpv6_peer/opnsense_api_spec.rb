# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_kea_dhcpv6_peer/opnsense_api'

describe Puppet::Type.type(:opn_kea_dhcpv6_peer).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_kea_dhcpv6_peer) }
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
    it 'fetches peers via search-only pattern' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchPeer', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'name' => 'primary-node', 'role' => 'primary', 'url' => 'http://[fd00::1]:8000' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('primary-node@opnsense01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('name' => 'primary-node', 'role' => 'primary')
    end

    it 'skips rows with empty name' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchPeer', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => '' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '#create' do
    it 'calls the addPeer endpoint with name injected' do
      resource = type_class.new(name: 'primary-node@opnsense01', config: { 'role' => 'primary', 'url' => 'http://[fd00::1]:8000' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'kea/dhcpv6/addPeer',
        hash_including('peer' => hash_including('name' => 'primary-node', 'role' => 'primary')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'primary-node@opnsense01', config: { 'role' => 'primary' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the delPeer endpoint' do
      resource = type_class.new(name: 'primary-node@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'primary-node@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('kea/dhcpv6/delPeer/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end
  end

  describe '#flush' do
    it 'calls the setPeer endpoint with name injected' do
      resource = type_class.new(name: 'primary-node@opnsense01', config: { 'role' => 'standby' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'primary-node@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'role' => 'standby' })
      expect(client).to receive(:post).with(
        'kea/dhcpv6/setPeer/aaa-bbb',
        hash_including('peer' => hash_including('name' => 'primary-node', 'role' => 'standby')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'primary-node@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'primary-node@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
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
