# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_reconfigure'

require 'puppet/type/opn_haproxy_server'
require 'puppet/provider/opn_haproxy_server/opnsense_api'

RSpec.describe Puppet::Type.type(:opn_haproxy_server).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_name) { :opn_haproxy_server }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    PuppetX::Opn::HaproxyReconfigure.instance_variable_set(:@devices_to_reconfigure, {})
    PuppetX::Opn::HaproxyReconfigure.instance_variable_set(:@devices_with_errors, {})
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'returns instances from the API' do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {}).and_return(
        'rows' => [
          { 'uuid' => 'aaa-bbb', 'name' => 'web01', 'address' => '10.0.0.1' },
        ],
      )

      instances = described_class.instances
      expect(instances.length).to eq(1)
      expect(instances[0].name).to eq('web01@fw01')
      expect(instances[0].get(:config)).to eq('name' => 'web01', 'address' => '10.0.0.1')
      expect(instances[0].get(:uuid)).to eq('aaa-bbb')
    end

    it 'skips rows with empty name' do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {}).and_return(
        'rows' => [
          { 'uuid' => 'aaa-bbb', 'name' => '' },
        ],
      )

      instances = described_class.instances
      expect(instances).to be_empty
    end

    it 'warns on API error' do
      allow(client).to receive(:post).and_raise(Puppet::Error, 'connection refused')
      expect(Puppet).to receive(:warning).with(%r{failed to fetch})

      described_class.instances
    end
  end

  describe '.prefetch' do
    it 'matches resources to instances' do
      allow(client).to receive(:post).with('haproxy/settings/search_servers', {}).and_return(
        'rows' => [
          { 'uuid' => 'aaa-bbb', 'name' => 'web01', 'address' => '10.0.0.1' },
        ],
      )

      resource = Puppet::Type.type(:opn_haproxy_server).new(
        name: 'web01@fw01',
        ensure: :present,
      )
      resources = { 'web01@fw01' => resource }

      described_class.prefetch(resources)
      expect(resource.provider.name).to eq('web01@fw01')
    end
  end

  describe '.post_resource_eval' do
    it 'delegates to HaproxyReconfigure.run' do
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:run)
      described_class.post_resource_eval
    end
  end

  describe '#create' do
    let(:resource) do
      Puppet::Type.type(:opn_haproxy_server).new(
        name: 'web01@fw01',
        ensure: :present,
        config: { 'address' => '10.0.0.1' },
      )
    end
    let(:provider) { described_class.new(resource: resource) }

    before(:each) do
      resource.provider = provider
    end

    it 'sends correct POST to add endpoint' do
      expect(client).to receive(:post).with(
        'haproxy/settings/add_server',
        { 'server' => { 'address' => '10.0.0.1', 'name' => 'web01' } },
      ).and_return({ 'result' => 'saved' })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)

      provider.create
    end

    it 'marks device for reconfigure' do
      allow(client).to receive(:post).and_return({ 'result' => 'saved' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)

      provider.create
    end

    it 'raises on failure' do
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)

      expect { provider.create }.to raise_error(Puppet::Error, %r{failed to create})
    end
  end

  describe '#destroy' do
    let(:resource) do
      Puppet::Type.type(:opn_haproxy_server).new(
        name: 'web01@fw01',
        ensure: :absent,
      )
    end
    let(:provider) do
      described_class.new(
        ensure: :present,
        name: 'web01@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'web01' },
      )
    end

    before(:each) do
      resource.provider = provider
    end

    it 'sends correct POST to del endpoint' do
      expect(client).to receive(:post).with(
        'haproxy/settings/del_server/aaa-bbb', {}
      ).and_return({ 'result' => 'deleted' })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)

      provider.destroy
    end

    it 'marks device for reconfigure' do
      allow(client).to receive(:post).and_return({ 'result' => 'deleted' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)

      provider.destroy
    end

    it 'raises on failure' do
      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)

      expect { provider.destroy }.to raise_error(Puppet::Error, %r{failed to delete})
    end
  end

  describe '#flush' do
    let(:resource) do
      Puppet::Type.type(:opn_haproxy_server).new(
        name: 'web01@fw01',
        ensure: :present,
        config: { 'address' => '10.0.0.2' },
      )
    end
    let(:provider) do
      described_class.new(
        ensure: :present,
        name: 'web01@fw01',
        device: 'fw01',
        uuid: 'aaa-bbb',
        config: { 'name' => 'web01', 'address' => '10.0.0.1' },
      )
    end

    before(:each) do
      resource.provider = provider
    end

    it 'sends correct POST to set endpoint' do
      provider.config = { 'address' => '10.0.0.2' }

      expect(client).to receive(:post).with(
        'haproxy/settings/set_server/aaa-bbb',
        { 'server' => { 'address' => '10.0.0.2', 'name' => 'web01' } },
      ).and_return({ 'result' => 'saved' })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)

      provider.flush
    end

    it 'does nothing without pending config' do
      provider.flush
      # No error raised, no API call made
    end

    it 'marks device for reconfigure' do
      provider.config = { 'address' => '10.0.0.2' }

      allow(client).to receive(:post).and_return({ 'result' => 'saved' })
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:mark).with('fw01', client)

      provider.flush
    end

    it 'raises on failure' do
      provider.config = { 'address' => '10.0.0.2' }

      allow(client).to receive(:post).and_return({ 'result' => 'failed' })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)

      expect { provider.flush }.to raise_error(Puppet::Error, %r{failed to update})
    end
  end
end
