# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/haproxy_uuid_resolver'

describe PuppetX::Opn::HaproxyUuidResolver do
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }
  let(:device) { 'fw01' }

  before(:each) do
    described_class.instance_variable_set(:@cache, {})
  end

  describe '.populate' do
    it 'fetches and caches endpoint data' do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {})
                                     .and_return({ 'rows' => [{ 'uuid' => 'aaa', 'name' => 'web01' }] })

      described_class.populate(client, device, 'haproxy/settings/search_servers')

      cache = described_class.instance_variable_get(:@cache)
      key = 'fw01:haproxy/settings/search_servers:uuid:name'
      expect(cache[key][:id_to_name]).to eq('aaa' => 'web01')
      expect(cache[key][:name_to_id]).to eq('web01' => 'aaa')
    end

    it 'supports custom id_field and name_field' do
      allow(client).to receive(:post).with('trust/ca/search', {})
                                     .and_return({ 'rows' => [{ 'refid' => 'ref1', 'descr' => 'My CA' }] })

      described_class.populate(client, device, 'trust/ca/search',
                               id_field: 'refid', name_field: 'descr')

      cache = described_class.instance_variable_get(:@cache)
      key = 'fw01:trust/ca/search:refid:descr'
      expect(cache[key][:id_to_name]).to eq('ref1' => 'My CA')
    end

    it 'uses GET when method is :get' do
      expect(client).to receive(:get).with('trust/crl/search')
                                     .and_return({ 'rows' => [{ 'refid' => 'r1', 'crl_descr' => 'CRL1' }] })

      described_class.populate(client, device, 'trust/crl/search',
                               id_field: 'refid', name_field: 'crl_descr', method: :get)
    end

    it 'does not re-fetch when already cached' do
      expect(client).to receive(:post).and_return({ 'rows' => [] }).once
      described_class.populate(client, device, 'haproxy/settings/search_servers')
      described_class.populate(client, device, 'haproxy/settings/search_servers')
    end
  end

  describe '.translate_to_names' do
    let(:relation_fields) do
      {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: true },
      }
    end

    before(:each) do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {})
                                     .and_return({ 'rows' => [
                                                   { 'uuid' => 'uuid1', 'name' => 'web01' },
                                                   { 'uuid' => 'uuid2', 'name' => 'web02' },
                                                 ] })
    end

    it 'translates UUIDs to names' do
      config = { 'linkedServers' => 'uuid1,uuid2', 'mode' => 'http' }
      result = described_class.translate_to_names(client, device, relation_fields, config)
      expect(result['linkedServers']).to eq('web01,web02')
      expect(result['mode']).to eq('http')
    end

    it 'falls back to original value if not found' do
      config = { 'linkedServers' => 'unknown_uuid' }
      result = described_class.translate_to_names(client, device, relation_fields, config)
      expect(result['linkedServers']).to eq('unknown_uuid')
    end

    it 'does not modify original config' do
      config = { 'linkedServers' => 'uuid1' }
      described_class.translate_to_names(client, device, relation_fields, config)
      expect(config['linkedServers']).to eq('uuid1')
    end
  end

  describe '.translate_to_uuids' do
    let(:relation_fields) do
      {
        'linkedServers' => { endpoint: 'haproxy/settings/search_servers', multiple: true },
        'healthCheck'   => { endpoint: 'haproxy/settings/search_healthchecks', multiple: false },
      }
    end

    before(:each) do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {})
                                     .and_return({ 'rows' => [
                                                   { 'uuid' => 'uuid1', 'name' => 'web01' },
                                                 ] })
      allow(client).to receive(:post).with('haproxy/settings/search_healthchecks', {})
                                     .and_return({ 'rows' => [
                                                   { 'uuid' => 'hc1', 'name' => 'http_check' },
                                                 ] })
    end

    it 'translates names to UUIDs' do
      config = { 'linkedServers' => 'web01', 'healthCheck' => 'http_check' }
      result = described_class.translate_to_uuids(client, device, relation_fields, config)
      expect(result['linkedServers']).to eq('uuid1')
      expect(result['healthCheck']).to eq('hc1')
    end

    it 'passes through UUIDs unchanged' do
      uuid = '12345678-1234-1234-1234-123456789abc'
      config = { 'healthCheck' => uuid }
      result = described_class.translate_to_uuids(client, device, relation_fields, config)
      expect(result['healthCheck']).to eq(uuid)
    end

    it 'raises on unresolved name' do
      config = { 'healthCheck' => 'nonexistent' }
      expect {
        described_class.translate_to_uuids(client, device, relation_fields, config)
      }.to raise_error(Puppet::Error, %r{cannot resolve 'nonexistent'})
    end
  end
end
