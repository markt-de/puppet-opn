# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_plugin/opnsense_api'

describe Puppet::Type.type(:opn_plugin).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_plugin) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
  end

  it_behaves_like 'opn provider basics'

  describe '.instances' do
    it 'fetches installed plugins from firmware info' do
      allow(client).to receive(:get).with('core/firmware/info')
                                    .and_return({ 'package' => [
                                                  { 'name' => 'os-haproxy', 'installed' => '1' },
                                                  { 'name' => 'os-zabbix-agent', 'installed' => '0' },
                                                  { 'name' => 'os-wireguard', 'installed' => '1' },
                                                ] })
      instances = described_class.instances
      expect(instances.size).to eq(2)
      expect(instances.map(&:name)).to contain_exactly('os-haproxy@fw01', 'os-wireguard@fw01')
    end

    it 'returns empty array when package key is missing' do
      allow(client).to receive(:get).with('core/firmware/info')
                                    .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'skips packages with empty names' do
      allow(client).to receive(:get).with('core/firmware/info')
                                    .and_return({ 'package' => [{ 'name' => '', 'installed' => '1' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:get).with('core/firmware/info')
                                    .and_return({ 'package' => [{ 'name' => 'os-haproxy', 'installed' => '1' }] })
      resource = type_class.new(name: 'os-haproxy@fw01')
      described_class.prefetch({ 'os-haproxy@fw01' => resource })
      expect(resource.provider.name).to eq('os-haproxy@fw01')
    end
  end

  describe '#create' do
    it 'calls the install endpoint' do
      resource = type_class.new(name: 'os-haproxy@fw01')
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with('core/firmware/install/os-haproxy', {})
                                      .and_return({})
      provider.create
    end
  end

  describe '#destroy' do
    it 'calls the remove endpoint' do
      resource = type_class.new(name: 'os-haproxy@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'os-haproxy@fw01', device: 'fw01',
                                     })
      expect(client).to receive(:post).with('core/firmware/remove/os-haproxy', {})
                                      .and_return({})
      provider.destroy
    end
  end
end
