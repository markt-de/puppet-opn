# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_zabbix_agent_alias/opnsense_api'
require 'puppet_x/opn/zabbix_agent_reconfigure'

describe Puppet::Type.type(:opn_zabbix_agent_alias).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_zabbix_agent_alias) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    PuppetX::Opn::ZabbixAgentReconfigure.instance_variable_set(:@devices_to_reconfigure, {})
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    let(:api_response) do
      {
        'zabbixagent' => {
          'aliases' => {
            'alias' => {
              'uuid1' => { 'key' => 'ping', 'sourceKey' => 'icmpping' },
            },
          },
          'userparameters' => { 'userparameter' => {} },
          'settings' => {},
        },
      }
    end

    it 'fetches aliases from nested response' do
      allow(client).to receive(:get).with('zabbixagent/settings/get')
                                    .and_return(api_response)
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('ping@fw01')
    end

    it 'stores uuid and device in property_hash' do
      allow(client).to receive(:get).with('zabbixagent/settings/get')
                                    .and_return(api_response)
      instances = described_class.instances
      hash = instances[0].instance_variable_get(:@property_hash)
      expect(hash[:uuid]).to eq('uuid1')
      expect(hash[:device]).to eq('fw01')
    end

    it 'stores config without id key' do
      response = {
        'zabbixagent' => {
          'aliases' => {
            'alias' => {
              'uuid1' => { 'key' => 'ping', 'sourceKey' => 'icmpping', 'id' => '1' },
            },
          },
        },
      }
      allow(client).to receive(:get).with('zabbixagent/settings/get')
                                    .and_return(response)
      instances = described_class.instances
      config = instances[0].instance_variable_get(:@property_hash)[:config]
      expect(config).not_to have_key('id')
      expect(config).to include('key' => 'ping', 'sourceKey' => 'icmpping')
    end

    it 'skips entries with empty key' do
      response = {
        'zabbixagent' => {
          'aliases' => {
            'alias' => {
              'uuid1' => { 'key' => '', 'sourceKey' => 'test' },
            },
          },
        },
      }
      allow(client).to receive(:get).with('zabbixagent/settings/get')
                                    .and_return(response)
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '#create' do
    it 'calls addAlias endpoint with key from name' do
      resource = type_class.new(name: 'ping@fw01', config: { 'sourceKey' => 'icmpping' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'zabbixagent/settings/addAlias',
        { 'alias' => hash_including('key' => 'ping', 'sourceKey' => 'icmpping') },
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'ping@fw01', config: { 'sourceKey' => 'icmpping' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls delAlias endpoint with uuid' do
      resource = type_class.new(name: 'ping@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'ping@fw01', device: 'fw01', uuid: 'uuid1',
                                     })
      expect(client).to receive(:post).with('zabbixagent/settings/delAlias/uuid1', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'ping@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'ping@fw01', device: 'fw01', uuid: 'uuid1',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'calls setAlias endpoint with uuid and pending config' do
      resource = type_class.new(name: 'ping@fw01', config: { 'sourceKey' => 'icmpping[,1]' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'ping@fw01', device: 'fw01', uuid: 'uuid1',
        config: { 'key' => 'ping', 'sourceKey' => 'icmpping' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'sourceKey' => 'icmpping[,1]' })
      expect(client).to receive(:post).with(
        'zabbixagent/settings/setAlias/uuid1',
        { 'alias' => hash_including('key' => 'ping', 'sourceKey' => 'icmpping[,1]') },
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'ping@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'ping@fw01', device: 'fw01', uuid: 'uuid1',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'ping@fw01', config: { 'sourceKey' => 'test' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'ping@fw01', device: 'fw01', uuid: 'uuid1',
                                     })
      provider.instance_variable_set(:@pending_config, { 'sourceKey' => 'test' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end

  describe '.post_resource_eval' do
    it 'delegates to ZabbixAgentReconfigure.run' do
      expect(PuppetX::Opn::ZabbixAgentReconfigure).to receive(:run)
      described_class.post_resource_eval
    end
  end
end
