# frozen_string_literal: true

require 'spec_helper'
require 'puppet/provider/opn_haproxy_settings/opnsense_api'
require 'puppet_x/opn/haproxy_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

describe Puppet::Type.type(:opn_haproxy_settings).provider(:opnsense_api) do
  let(:provider_class) { described_class }
  let(:type_class) { Puppet::Type.type(:opn_haproxy_settings) }
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:device_names).and_return(['fw01'])
    allow(PuppetX::Opn::ApiClient).to receive(:from_device).with('fw01').and_return(client)
    PuppetX::Opn::HaproxyReconfigure.instance_variable_set(:@devices_to_reconfigure, {})
    PuppetX::Opn::HaproxyReconfigure.instance_variable_set(:@devices_with_errors, {})
    PuppetX::Opn::HaproxyUuidResolver.instance_variable_set(:@cache, {})
  end

  it_behaves_like 'opn provider basics'
  it_behaves_like 'opn provider with config property'

  describe '.instances' do
    it 'fetches settings via GET' do
      allow(client).to receive(:get).with('haproxy/settings/get')
                                    .and_return({ 'haproxy' => { 'general' => { 'enabled' => '1' }, 'maintenance' => {} } })
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_names)
        .and_return({ 'general' => { 'enabled' => '1' }, 'maintenance' => {} })
      instances = described_class.instances
      expect(instances.size).to eq(1)
      expect(instances[0].name).to eq('fw01')
    end
  end

  describe '#create' do
    it 'saves settings and marks reconfigure' do
      resource = type_class.new(name: 'fw01', config: { 'general' => { 'enabled' => '1' } })
      provider = described_class.new
      resource.provider = provider
      allow(PuppetX::Opn::HaproxyUuidResolver).to receive(:translate_to_uuids)
        .and_return({ 'general' => { 'enabled' => '1' } })
      allow(PuppetX::Opn::HaproxyReconfigure).to receive(:mark)
      expect(client).to receive(:post).with('haproxy/settings/set', anything)
                                      .and_return({ 'result' => 'saved' })
      provider.create
    end
  end

  describe '.post_resource_eval' do
    it 'delegates to HaproxyReconfigure.run' do
      expect(PuppetX::Opn::HaproxyReconfigure).to receive(:run)
      described_class.post_resource_eval
    end
  end
end
