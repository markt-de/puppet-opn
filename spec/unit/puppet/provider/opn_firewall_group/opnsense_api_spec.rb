# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_firewall_group/opnsense_api'

describe Puppet::Type.type(:opn_firewall_group).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_firewall_group) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    described_class.instance_variable_set(:@devices_to_reconfigure, {})
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches groups from the API' do
      allow(client).to receive(:post).with('firewall/group/search_item', {})
                                     .and_return({ 'rows' => [{
                                                   'uuid' => 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'ifname' => 'mygroup', 'members' => 'lan,wan',
                                                 }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('mygroup@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('ifname' => 'mygroup', 'members' => 'lan,wan')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).not_to have_key('uuid')
    end

    it 'skips system-managed groups with non-UUID identifiers' do
      allow(client).to receive(:post).with('firewall/group/search_item', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'enc0', 'ifname' => 'ipsec', 'members' => '' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'skips rows with empty ifname' do
      allow(client).to receive(:post).with('firewall/group/search_item', {})
                                     .and_return({ 'rows' => [{
                                                   'uuid' => 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'ifname' => '', 'members' => '',
                                                 }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:post).with('firewall/group/search_item', {})
                                     .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:post).with('firewall/group/search_item', {})
                                     .and_return({ 'rows' => [{
                                                   'uuid' => 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'ifname' => 'mygroup', 'members' => 'lan,wan',
                                                 }] })
      resource = type_class.new(name: 'mygroup@fw01')
      described_class.prefetch({ 'mygroup@fw01' => resource })
      expect(resource.provider.name).to eq('mygroup@fw01')
    end
  end

  describe '#create' do
    it 'calls the add_item endpoint' do
      resource = type_class.new(name: 'mygroup@fw01', config: { 'members' => 'lan,wan' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'firewall/group/add_item',
        hash_including('group' => hash_including('ifname' => 'mygroup', 'members' => 'lan,wan')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'mygroup@fw01', config: { 'members' => 'lan' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'mygroup@fw01', config: { 'members' => 'lan,wan' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('firewall/group/add_item', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.create
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '#destroy' do
    it 'calls the del_item endpoint' do
      resource = type_class.new(name: 'mygroup@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('firewall/group/del_item/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'mygroup@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'mygroup@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).with('firewall/group/del_item/aaa-bbb', {})
                                     .and_return({ 'result' => 'deleted' })
      provider.destroy
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '#flush' do
    it 'calls the set_item endpoint when config has changed' do
      resource = type_class.new(name: 'mygroup@fw01', config: { 'members' => 'lan' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
        config: { 'ifname' => 'mygroup', 'members' => 'lan,wan' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'members' => 'lan' })
      expect(client).to receive(:post).with(
        'firewall/group/set_item/aaa-bbb',
        hash_including('group' => hash_including('ifname' => 'mygroup', 'members' => 'lan')),
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'mygroup@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'mygroup@fw01', config: { 'members' => 'lan' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'members' => 'lan' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end

    it 'marks device for reconfigure' do
      resource = type_class.new(name: 'mygroup@fw01', config: { 'members' => 'lan' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'mygroup@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'members' => 'lan' })
      allow(client).to receive(:post).with('firewall/group/set_item/aaa-bbb', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.flush
      expect(described_class.devices_to_reconfigure).to have_key('fw01')
    end
  end

  describe '.post_resource_eval' do
    it 'calls reconfigure for each device that had changes' do
      described_class.devices_to_reconfigure['fw01'] = client
      expect(client).to receive(:post).with('firewall/group/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })
      described_class.post_resource_eval
    end

    it 'clears devices_to_reconfigure after reconfigure' do
      described_class.devices_to_reconfigure['fw01'] = client
      allow(client).to receive(:post).with('firewall/group/reconfigure', {})
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
