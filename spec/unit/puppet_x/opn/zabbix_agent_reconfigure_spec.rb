# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/zabbix_agent_reconfigure'

describe PuppetX::Opn::ZabbixAgentReconfigure do
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    described_class.instance_variable_set(:@devices_to_reconfigure, {})
  end

  describe '.mark' do
    it 'registers a device' do
      described_class.mark('fw01', client)
      expect(described_class.instance_variable_get(:@devices_to_reconfigure)).to have_key('fw01')
    end

    it 'does not overwrite an existing entry' do
      other_client = instance_double('PuppetX::Opn::ApiClient')
      described_class.mark('fw01', client)
      described_class.mark('fw01', other_client)
      expect(described_class.instance_variable_get(:@devices_to_reconfigure)['fw01']).to eq(client)
    end
  end

  describe '.run' do
    it 'reconfigures each registered device' do
      described_class.mark('fw01', client)
      expect(client).to receive(:post).with('zabbixagent/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })

      described_class.run
    end

    it 'clears tracking hash after run' do
      described_class.mark('fw01', client)
      allow(client).to receive(:post).and_return({ 'status' => 'ok' })

      described_class.run

      expect(described_class.instance_variable_get(:@devices_to_reconfigure)).to be_empty
    end

    it 'logs warning on unexpected status' do
      described_class.mark('fw01', client)
      allow(client).to receive(:post).and_return({ 'status' => 'error' })

      expect(Puppet).to receive(:warning).with(%r{unexpected status})
      described_class.run
    end

    it 'handles API errors gracefully' do
      described_class.mark('fw01', client)
      allow(client).to receive(:post).and_raise(Puppet::Error, 'connection failed')

      expect(Puppet).to receive(:err).with(%r{failed})
      described_class.run
    end
  end
end
