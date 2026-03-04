# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_kea_dhcpv6_pd_pool/opnsense_api'

describe Puppet::Type.type(:opn_kea_dhcpv6_pd_pool).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_kea_dhcpv6_pd_pool) }
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
    it 'fetches PD pools via search-only pattern' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchPdPool', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'description' => 'Customer PD', 'subnet' => 'fd00::/64', 'prefix' => 'fd00:1::/48' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('Customer PD@opnsense01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('description' => 'Customer PD')
    end

    it 'skips rows with empty description' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchPdPool', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'description' => '' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '#create' do
    it 'calls the addPdPool endpoint with IdResolver translation' do
      resource = type_class.new(name: 'Customer PD@opnsense01', config: { 'subnet' => 'fd00::/64', 'prefix' => 'fd00:1::/48' })
      provider = described_class.new
      resource.provider = provider
      allow(PuppetX::Opn::IdResolver).to receive(:translate_to_uuids)
        .and_return({ 'description' => 'Customer PD', 'subnet' => 'uuid-123', 'prefix' => 'fd00:1::/48' })
      expect(client).to receive(:post).with(
        'kea/dhcpv6/addPdPool',
        hash_including('pd_pool' => hash_including('description' => 'Customer PD')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'Customer PD@opnsense01', config: { 'subnet' => 'fd00::/64' })
      provider = described_class.new
      resource.provider = provider
      allow(PuppetX::Opn::IdResolver).to receive(:translate_to_uuids).and_return({})
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the delPdPool endpoint' do
      resource = type_class.new(name: 'Customer PD@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Customer PD@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('kea/dhcpv6/delPdPool/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end
  end

  describe '#flush' do
    it 'calls the setPdPool endpoint with IdResolver translation' do
      resource = type_class.new(name: 'Customer PD@opnsense01', config: { 'subnet' => 'fd00::/64' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Customer PD@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'subnet' => 'fd00::/64' })
      allow(PuppetX::Opn::IdResolver).to receive(:translate_to_uuids)
        .and_return({ 'description' => 'Customer PD', 'subnet' => 'uuid-123' })
      expect(client).to receive(:post).with(
        'kea/dhcpv6/setPdPool/aaa-bbb',
        hash_including('pd_pool' => hash_including('description' => 'Customer PD')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'Customer PD@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Customer PD@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
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
