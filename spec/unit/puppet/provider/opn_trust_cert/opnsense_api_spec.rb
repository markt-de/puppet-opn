# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_trust_cert/opnsense_api'

describe Puppet::Type.type(:opn_trust_cert).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_trust_cert) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches certificates from the API' do
      allow(client).to receive(:post).with('trust/cert/search', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'descr' => 'Web Server Cert', 'cert_type' => 'server' }] })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('Web Server Cert@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('descr' => 'Web Server Cert', 'cert_type' => 'server')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).not_to have_key('uuid')
    end

    it 'skips rows with empty descr' do
      allow(client).to receive(:post).with('trust/cert/search', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'descr' => '', 'cert_type' => 'server' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:post).with('trust/cert/search', {})
                                     .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:post).with('trust/cert/search', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa-bbb', 'descr' => 'Web Server Cert', 'cert_type' => 'server' }] })
      resource = type_class.new(name: 'Web Server Cert@fw01')
      described_class.prefetch({ 'Web Server Cert@fw01' => resource })
      expect(resource.provider.name).to eq('Web Server Cert@fw01')
    end
  end

  describe '#create' do
    it 'calls the add endpoint' do
      resource = type_class.new(name: 'Web Server Cert@fw01', config: { 'cert_type' => 'server' })
      provider = described_class.new
      resource.provider = provider
      expect(client).to receive(:post).with(
        'trust/cert/add',
        hash_including('cert' => hash_including('descr' => 'Web Server Cert', 'cert_type' => 'server')),
      ).and_return({ 'result' => 'saved' })
      provider.create
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'Web Server Cert@fw01', config: { 'cert_type' => 'server' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the del endpoint' do
      resource = type_class.new(name: 'Web Server Cert@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Web Server Cert@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      expect(client).to receive(:post).with('trust/cert/del/aaa-bbb', {})
                                      .and_return({ 'result' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'Web Server Cert@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Web Server Cert@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'calls the set endpoint when config has changed' do
      resource = type_class.new(name: 'Web Server Cert@fw01', config: { 'digest' => 'sha256' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Web Server Cert@fw01', device: 'fw01', uuid: 'aaa-bbb',
        config: { 'descr' => 'Web Server Cert', 'digest' => 'sha512' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'digest' => 'sha256' })
      expect(client).to receive(:post).with(
        'trust/cert/set/aaa-bbb',
        { 'cert' => { 'descr' => 'Web Server Cert' } },
      ).and_return({ 'result' => 'saved' })
      provider.flush
    end

    it 'strips VOLATILE_FIELDS from config on flush' do
      resource = type_class.new(name: 'Web Server Cert@fw01', config: { 'digest' => 'sha256', 'key_type' => 'RSA' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Web Server Cert@fw01', device: 'fw01', uuid: 'aaa-bbb',
        config: { 'descr' => 'Web Server Cert', 'digest' => 'sha512' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'digest' => 'sha256', 'key_type' => 'RSA' })
      expect(client).to receive(:post).with('trust/cert/set/aaa-bbb', anything) do |_endpoint, payload|
        expect(payload['cert']).not_to have_key('key_type')
        { 'result' => 'saved' }
      end
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'Web Server Cert@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Web Server Cert@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'Web Server Cert@fw01', config: { 'digest' => 'sha256' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'Web Server Cert@fw01', device: 'fw01', uuid: 'aaa-bbb',
                                     })
      provider.instance_variable_set(:@pending_config, { 'digest' => 'sha256' })
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
