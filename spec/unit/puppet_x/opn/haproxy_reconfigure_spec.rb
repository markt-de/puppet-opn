# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/haproxy_reconfigure'

describe PuppetX::Opn::HaproxyReconfigure do
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    described_class.instance_variable_set(:@devices_to_reconfigure, {})
    described_class.instance_variable_set(:@devices_with_errors, {})
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

  describe '.mark_error' do
    it 'registers an error device' do
      described_class.mark_error('fw01')
      expect(described_class.instance_variable_get(:@devices_with_errors)).to have_key('fw01')
    end
  end

  describe '.run' do
    it 'runs configtest and reconfigure on success' do
      described_class.mark('fw01', client)
      expect(client).to receive(:get).with('haproxy/service/configtest')
                                     .and_return({ 'result' => 'Configuration file is valid' })
      expect(client).to receive(:post).with('haproxy/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })

      described_class.run
    end

    it 'skips reconfigure on ALERT' do
      described_class.mark('fw01', client)
      allow(client).to receive(:get).with('haproxy/service/configtest')
                                    .and_return({ 'result' => '[ALERT] some error' })
      expect(client).not_to receive(:post)

      described_class.run
    end

    it 'proceeds on WARNING' do
      described_class.mark('fw01', client)
      allow(client).to receive(:get).with('haproxy/service/configtest')
                                    .and_return({ 'result' => '[WARNING] some warning' })
      expect(client).to receive(:post).with('haproxy/service/reconfigure', {})
                                      .and_return({ 'status' => 'ok' })

      described_class.run
    end

    it 'skips errored devices' do
      described_class.mark('fw01', client)
      described_class.mark_error('fw01')
      expect(client).not_to receive(:get)
      allow(client).to receive(:post)

      described_class.run
    end

    it 'clears tracking hashes after run' do
      described_class.mark('fw01', client)
      allow(client).to receive_messages(get: { 'result' => 'ok' }, post: { 'status' => 'ok' })

      described_class.run

      expect(described_class.instance_variable_get(:@devices_to_reconfigure)).to be_empty
      expect(described_class.instance_variable_get(:@devices_with_errors)).to be_empty
    end
  end
end
