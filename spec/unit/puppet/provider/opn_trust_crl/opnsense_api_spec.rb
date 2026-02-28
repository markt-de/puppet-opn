# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_trust_crl/opnsense_api'

describe Puppet::Type.type(:opn_trust_crl).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_trust_crl) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches CRLs from the API' do
      allow(client).to receive(:get).with('trust/crl/search')
                                    .and_return({ 'rows' => [{ 'descr' => 'My Root CA', 'refid' => 'abc123', 'crl_descr' => 'CRL for My Root CA' }] })
      allow(client).to receive(:get).with('trust/crl/get/abc123')
                                    .and_return({ 'crl' => { 'descr' => 'CRL for My Root CA', 'lifetime' => '9999' } })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('My Root CA@fw01')
      expect(instances[0].instance_variable_get(:@property_hash)[:caref]).to eq('abc123')
      expect(instances[0].instance_variable_get(:@property_hash)[:config]).to include('descr' => 'CRL for My Root CA', 'lifetime' => '9999')
    end

    it 'skips rows with empty crl_descr' do
      allow(client).to receive(:get).with('trust/crl/search')
                                    .and_return({ 'rows' => [{ 'descr' => 'My Root CA', 'refid' => 'abc123', 'crl_descr' => '' }] })
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end

    it 'returns empty array when rows key is missing' do
      allow(client).to receive(:get).with('trust/crl/search')
                                    .and_return({})
      instances = described_class.instances
      expect(instances.size).to eq(0)
    end
  end

  describe '.prefetch' do
    it 'matches instances to resources' do
      allow(client).to receive(:get).with('trust/crl/search')
                                    .and_return({ 'rows' => [{ 'descr' => 'My Root CA', 'refid' => 'abc123', 'crl_descr' => 'CRL for My Root CA' }] })
      allow(client).to receive(:get).with('trust/crl/get/abc123')
                                    .and_return({ 'crl' => { 'descr' => 'CRL for My Root CA', 'lifetime' => '9999' } })
      resource = type_class.new(name: 'My Root CA@fw01')
      described_class.prefetch({ 'My Root CA@fw01' => resource })
      expect(resource.provider.name).to eq('My Root CA@fw01')
    end
  end

  describe '#create' do
    it 'resolves caref and calls the set endpoint' do
      resource = type_class.new(name: 'My Root CA@fw01', config: { 'descr' => 'CRL for My Root CA', 'lifetime' => '9999' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:get).with('trust/ca/caList')
                                    .and_return({ 'rows' => [{ 'descr' => 'My Root CA', 'caref' => 'abc123' }] })
      expect(client).to receive(:post).with(
        'trust/crl/set/abc123',
        hash_including('crl' => hash_including('descr' => 'CRL for My Root CA', 'lifetime' => '9999')),
      ).and_return({ 'status' => 'saved' })
      provider.create
    end

    it 'raises when CA is not found' do
      resource = type_class.new(name: 'Unknown CA@fw01', config: { 'descr' => 'CRL' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:get).with('trust/ca/caList')
                                    .and_return({ 'rows' => [] })
      expect { provider.create }.to raise_error(Puppet::Error, %r{CA 'Unknown CA' not found})
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'My Root CA@fw01', config: { 'descr' => 'CRL' })
      provider = described_class.new
      resource.provider = provider
      allow(client).to receive(:get).with('trust/ca/caList')
                                    .and_return({ 'rows' => [{ 'descr' => 'My Root CA', 'caref' => 'abc123' }] })
      allow(client).to receive(:post).and_return({ 'status' => 'failed' })
      expect { provider.create }.to raise_error(Puppet::Error)
    end
  end

  describe '#destroy' do
    it 'calls the del endpoint with caref' do
      resource = type_class.new(name: 'My Root CA@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'My Root CA@fw01', device: 'fw01', caref: 'abc123',
                                     })
      expect(client).to receive(:post).with('trust/crl/del/abc123', {})
                                      .and_return({ 'status' => 'deleted' })
      provider.destroy
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'My Root CA@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'My Root CA@fw01', device: 'fw01', caref: 'abc123',
                                     })
      allow(client).to receive(:post).and_return({ 'status' => 'failed' })
      expect { provider.destroy }.to raise_error(Puppet::Error)
    end
  end

  describe '#flush' do
    it 'calls the set endpoint with caref when config has changed' do
      resource = type_class.new(name: 'My Root CA@fw01', config: { 'lifetime' => '3650' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'My Root CA@fw01', device: 'fw01', caref: 'abc123',
        config: { 'descr' => 'CRL for My Root CA', 'lifetime' => '9999' },
                                     })
      provider.instance_variable_set(:@pending_config, { 'lifetime' => '3650' })
      expect(client).to receive(:post).with(
        'trust/crl/set/abc123',
        hash_including('crl' => hash_including('lifetime' => '3650')),
      ).and_return({ 'status' => 'saved' })
      provider.flush
    end

    it 'does nothing when no pending config' do
      resource = type_class.new(name: 'My Root CA@fw01')
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'My Root CA@fw01', device: 'fw01', caref: 'abc123',
                                     })
      provider.flush
      # No API call expected
    end

    it 'raises on failure' do
      resource = type_class.new(name: 'My Root CA@fw01', config: { 'lifetime' => '3650' })
      provider = described_class.new
      resource.provider = provider
      provider.instance_variable_set(:@property_hash, {
                                       ensure: :present, name: 'My Root CA@fw01', device: 'fw01', caref: 'abc123',
                                     })
      provider.instance_variable_set(:@pending_config, { 'lifetime' => '3650' })
      allow(client).to receive(:post).and_return({ 'status' => 'failed' })
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end
end
