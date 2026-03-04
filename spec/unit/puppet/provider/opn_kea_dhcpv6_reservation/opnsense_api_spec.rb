# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_kea_dhcpv6_reservation/opnsense_api'

describe Puppet::Type.type(:opn_kea_dhcpv6_reservation).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_kea_dhcpv6_reservation) }
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
    it 'fetches reservations via search-only pattern' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchReservation', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'description' => 'Mail Server', 'subnet' => 'fd00::/64', 'ip_address' => 'fd00::10' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('Mail Server@opnsense01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('description' => 'Mail Server')
    end

    it 'skips rows with empty description' do
      allow(client).to receive(:post).with('kea/dhcpv6/searchReservation', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'description' => '' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '#create' do
    it 'calls the addReservation endpoint with IdResolver translation' do
      resource = type_class.new(name: 'Mail Server@opnsense01', config: { 'subnet' => 'fd00::/64', 'ip_address' => 'fd00::10' })
      provider = described_class.new
      resource.provider = provider
      allow(PuppetX::Opn::IdResolver).to receive(:translate_to_uuids)
        .and_return({ 'description' => 'Mail Server', 'subnet' => 'uuid-123', 'ip_address' => 'fd00::10' })
      expect(client).to receive(:post).with(
        'kea/dhcpv6/addReservation',
        hash_including('reservation' => hash_including('description' => 'Mail Server')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'Mail Server@opnsense01', config: { 'subnet' => 'fd00::/64' })
      provider = described_class.new
      resource.provider = provider
      allow(PuppetX::Opn::IdResolver).to receive(:translate_to_uuids).and_return({})
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the delReservation endpoint' do
      resource = type_class.new(name: 'Mail Server@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Mail Server@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('kea/dhcpv6/delReservation/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end
  end

  describe '#flush' do
    it 'calls the setReservation endpoint with IdResolver translation' do
      resource = type_class.new(name: 'Mail Server@opnsense01', config: { 'subnet' => 'fd00::/64' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Mail Server@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'subnet' => 'fd00::/64' })
      allow(PuppetX::Opn::IdResolver).to receive(:translate_to_uuids)
        .and_return({ 'description' => 'Mail Server', 'subnet' => 'uuid-123' })
      expect(client).to receive(:post).with(
        'kea/dhcpv6/setReservation/aaa-bbb',
        hash_including('reservation' => hash_including('description' => 'Mail Server')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'Mail Server@opnsense01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Mail Server@opnsense01', device: 'opnsense01', uuid: 'aaa-bbb',
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
