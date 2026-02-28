# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_zabbix_agent/opnsense_api'
require 'puppet_x/opn/zabbix_agent_reconfigure'

describe Puppet::Type.type(:opn_zabbix_agent).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_zabbix_agent) }
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
          'settings' => { 'main' => { 'enabled' => '1' } },
          'local' => { 'localItems' => {} },
          'userparameters' => { 'userparameter' => {} },
          'aliases' => { 'alias' => {} },
        },
      }
    end

    it 'fetches settings via GET' do
      allow(client).to receive(:get).with('zabbixagent/settings/get')
                                    .and_return(api_response)
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('fw01')
    end

    it 'excludes userparameters and aliases from config' do
      allow(client).to receive(:get).with('zabbixagent/settings/get')
                                    .and_return(api_response)
      instances = described_class.instances
      config = instances[0].instance_variable_get(:@property_hash)[:config]
      expect(config).to have_key('settings')
      expect(config).to have_key('local')
      expect(config).not_to have_key('userparameters')
      expect(config).not_to have_key('aliases')
    end
  end

  describe '#create' do
    it 'saves settings via POST' do
      config = { 'settings' => { 'main' => { 'enabled' => '1' } } }
      resource = type_class.new(name: 'fw01', config: config)
      provider = described_class.new
      resource.provider = provider
      allow(PuppetX::Opn::ZabbixAgentReconfigure).to receive(:mark)
      expect(client).to receive(:post).with(
        'zabbixagent/settings/set',
        hash_including('zabbixagent' => config),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'marks device for reconfigure' do
      config = { 'settings' => { 'main' => { 'enabled' => '1' } } }
      resource = type_class.new(name: 'fw01', config: config)
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).with('zabbixagent/settings/set', anything)
                                     .and_return({ 'result' => 'saved' })
      provider.create
      expect(PuppetX::Opn::ZabbixAgentReconfigure.instance_variable_get(:@devices_to_reconfigure)).to have_key('fw01')
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'fw01', config: { 'settings' => {} })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'saves pending config via POST' do
      new_config = { 'settings' => { 'main' => { 'enabled' => '0' } } }
      resource = type_class.new(name: 'fw01', config: new_config)
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'fw01',
        config: { 'settings' => { 'main' => { 'enabled' => '1' } } },
                                     })
      provider.instance_variable_set(:@pending_config, new_config)
      expect(client).to receive(:post).with(
        'zabbixagent/settings/set',
        hash_including('zabbixagent' => new_config),
      ).and_return({ 'result' => 'saved' })
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

  describe '.post_resource_eval' do
    it 'delegates to ZabbixAgentReconfigure.run' do
      expect(PuppetX::Opn::ZabbixAgentReconfigure).to receive(:run)
      described_class.post_resource_eval
    end
  end
end
