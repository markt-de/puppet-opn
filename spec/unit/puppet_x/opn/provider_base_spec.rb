# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/provider_base'

describe PuppetX::Opn::ProviderBase do
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  # Anonymous class that includes the mixin (simulates a Provider).
  let(:test_provider_class) do
    Class.new do
      extend PuppetX::Opn::ProviderBase::ClassMethods
      include PuppetX::Opn::ProviderBase::InstanceMethods

      attr_accessor :resource

      def initialize(property_hash = {})
        @property_hash = property_hash
      end

      def name
        @property_hash[:name]
      end
    end
  end

  before(:each) do
    allow(PuppetX::Opn::ApiClient).to receive(:from_device)
      .with('opnsense01').and_return(client)
  end

  # -- ClassMethods --

  describe 'ClassMethods' do
    describe '.api_client' do
      it 'delegates to ApiClient.from_device' do
        expect(test_provider_class.api_client('opnsense01')).to eq(client)
      end
    end

    describe '.prefetch' do
      it 'matches instances to resources by name' do
        inst = test_provider_class.new(
          ensure: :present, name: 'test@opnsense01',
        )
        allow(test_provider_class).to receive(:instances).and_return([inst])

        resource = instance_double('Puppet::Type', provider: nil)
        expect(resource).to receive(:provider=).with(inst)
        resources = { 'test@opnsense01' => resource }
        test_provider_class.prefetch(resources)
      end

      it 'ignores resources without matching instance' do
        allow(test_provider_class).to receive(:instances).and_return([])
        resource = instance_double('Puppet::Type')
        # provider= must NOT be called
        resources = { 'missing@opnsense01' => resource }
        test_provider_class.prefetch(resources)
      end
    end
  end

  # -- InstanceMethods --

  describe 'InstanceMethods' do
    describe '#exists?' do
      it 'returns true when ensure is :present' do
        provider = test_provider_class.new(ensure: :present)
        expect(provider.exists?).to be true
      end

      it 'returns false when hash is empty' do
        provider = test_provider_class.new({})
        expect(provider.exists?).to be false
      end

      it 'returns false when ensure is :absent' do
        provider = test_provider_class.new(ensure: :absent)
        expect(provider.exists?).to be false
      end
    end

    describe '#config / #config=' do
      it '#config returns property_hash[:config]' do
        provider = test_provider_class.new(config: { 'k' => 'v' })
        expect(provider.config).to eq('k' => 'v')
      end

      it '#config= stores pending_config' do
        provider = test_provider_class.new({})
        provider.config = { 'new' => 'val' }
        expect(provider.instance_variable_get(:@pending_config)).to eq('new' => 'val')
      end
    end

    describe '#api_client (private)' do
      it 'prefers device from property_hash' do
        provider = test_provider_class.new(device: 'opnsense01')
        expect(provider.send(:api_client)).to eq(client)
      end

      it 'falls back to resource[:device]' do
        provider = test_provider_class.new({})
        resource = instance_double('Puppet::Type')
        allow(resource).to receive(:[]).with(:device).and_return('opnsense01')
        provider.resource = resource
        expect(provider.send(:api_client)).to eq(client)
      end
    end

    describe '#resource_item_name (private)' do
      it 'extracts the part before @' do
        provider = test_provider_class.new({})
        resource = instance_double('Puppet::Type')
        allow(resource).to receive(:[]).with(:name)
                                       .and_return('my_item@opnsense01')
        provider.resource = resource
        expect(provider.send(:resource_item_name)).to eq('my_item')
      end

      it 'handles names without @ correctly' do
        provider = test_provider_class.new({})
        resource = instance_double('Puppet::Type')
        allow(resource).to receive(:[]).with(:name).and_return('simple')
        provider.resource = resource
        expect(provider.send(:resource_item_name)).to eq('simple')
      end
    end
  end

  # -- normalize_config Helpers --

  describe 'normalize_config' do
    describe '.normalize_config (class method)' do
      it 'normalizes selection hashes to comma-separated strings' do
        input = {
          'opt1' => { 'value' => 'Option 1', 'selected' => 1 },
          'opt2' => { 'value' => 'Option 2', 'selected' => 0 },
          'opt3' => { 'value' => 'Option 3', 'selected' => 1 },
        }
        expect(test_provider_class.normalize_config(input)).to eq('opt1,opt3')
      end

      it 'recurses into nested hashes' do
        input = {
          'section' => {
            'field' => {
              'a' => { 'value' => 'A', 'selected' => 1 },
              'b' => { 'value' => 'B', 'selected' => 0 },
            },
            'plain' => 'value',
          },
        }
        result = test_provider_class.normalize_config(input)
        expect(result).to eq(
          'section' => { 'field' => 'a', 'plain' => 'value' },
        )
      end

      it 'returns non-Hash values unchanged' do
        expect(test_provider_class.normalize_config('string')).to eq('string')
        expect(test_provider_class.normalize_config(nil)).to be_nil
      end

      it 'returns empty hashes unchanged' do
        expect(test_provider_class.normalize_config({})).to eq({})
      end
    end

    describe '.selection_hash? (class method)' do
      it 'detects selection hashes' do
        hash = { 'a' => { 'value' => 'x', 'selected' => 1 } }
        expect(test_provider_class.selection_hash?(hash)).to be true
      end

      it 'rejects normal hashes' do
        expect(test_provider_class.selection_hash?({ 'key' => 'val' })).to be false
      end

      it 'rejects empty hashes' do
        expect(test_provider_class.selection_hash?({})).to be false
      end
    end

    describe '.normalize_selection (class method)' do
      it 'collapses selected keys to comma-separated string' do
        input = {
          'opt1' => { 'value' => 'Option 1', 'selected' => 1 },
          'opt2' => { 'value' => 'Option 2', 'selected' => 0 },
          'opt3' => { 'value' => 'Option 3', 'selected' => 1 },
        }
        expect(test_provider_class.normalize_selection(input)).to eq('opt1,opt3')
      end

      it 'returns empty string when nothing selected' do
        input = {
          'opt1' => { 'value' => 'Option 1', 'selected' => 0 },
        }
        expect(test_provider_class.normalize_selection(input)).to eq('')
      end
    end
  end
end
