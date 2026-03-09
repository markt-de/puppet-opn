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

  # -- ReconfigureErrorTracking --

  describe 'ReconfigureErrorTracking' do
    # Clean up ServiceReconfigure state after each test.
    after(:each) do
      PuppetX::Opn::ServiceReconfigure.reset!
    end

    # Provider class with reconfigure_group declared.
    let(:tracked_provider_class) do
      # Register the group so ServiceReconfigure[:test_group] works.
      PuppetX::Opn::ServiceReconfigure.register(:test_group,
        endpoint: 'test/reconfigure', log_prefix: 'opn_test')

      Class.new do
        extend PuppetX::Opn::ProviderBase::ClassMethods
        include PuppetX::Opn::ProviderBase::InstanceMethods
        reconfigure_group :test_group

        attr_accessor :resource

        def initialize(property_hash = {})
          @property_hash = property_hash
        end

        # Stub create/destroy/flush that raise on demand.
        def create
          raise Puppet::Error, 'create failed' if @fail_on_create
        end

        def destroy
          raise Puppet::Error, 'destroy failed' if @fail_on_destroy
        end

        def flush
          raise Puppet::Error, 'flush failed' if @fail_on_flush
        end

        # Test helpers to trigger failures.
        def fail_on_create!
          @fail_on_create = true
        end

        def fail_on_destroy!
          @fail_on_destroy = true
        end

        def fail_on_flush!
          @fail_on_flush = true
        end
      end
    end

    describe '.reconfigure_group_name' do
      it 'returns the declared group name' do
        expect(tracked_provider_class.reconfigure_group_name).to eq(:test_group)
      end

      it 'returns nil for providers without reconfigure_group' do
        expect(test_provider_class.reconfigure_group_name).to be_nil
      end
    end

    describe 'error tracking on create' do
      it 'calls mark_error when create raises' do
        provider = tracked_provider_class.new(device: 'opnsense01')
        provider.resource = instance_double('Puppet::Type')
        provider.fail_on_create!
        expect(PuppetX::Opn::ServiceReconfigure[:test_group])
          .to receive(:mark_error).with('opnsense01')
        expect { provider.create }.to raise_error(Puppet::Error, %r{create failed})
      end

      it 'does not call mark_error when create succeeds' do
        provider = tracked_provider_class.new(device: 'opnsense01')
        provider.resource = instance_double('Puppet::Type')
        expect(PuppetX::Opn::ServiceReconfigure[:test_group])
          .not_to receive(:mark_error)
        provider.create
      end
    end

    describe 'error tracking on destroy' do
      it 'calls mark_error when destroy raises' do
        provider = tracked_provider_class.new(device: 'opnsense01')
        provider.resource = instance_double('Puppet::Type')
        provider.fail_on_destroy!
        expect(PuppetX::Opn::ServiceReconfigure[:test_group])
          .to receive(:mark_error).with('opnsense01')
        expect { provider.destroy }.to raise_error(Puppet::Error, %r{destroy failed})
      end
    end

    describe 'error tracking on flush' do
      it 'calls mark_error when flush raises' do
        provider = tracked_provider_class.new(device: 'opnsense01')
        provider.resource = instance_double('Puppet::Type')
        provider.fail_on_flush!
        expect(PuppetX::Opn::ServiceReconfigure[:test_group])
          .to receive(:mark_error).with('opnsense01')
        expect { provider.flush }.to raise_error(Puppet::Error, %r{flush failed})
      end
    end

    describe 'singleton fallback to resource[:name]' do
      it 'uses resource[:name] when device is not available' do
        # Singleton providers have no :device param — property_hash has no
        # :device, and resource[:device] returns nil.
        provider = tracked_provider_class.new({})
        resource = instance_double('Puppet::Type')
        allow(resource).to receive(:[]).with(:device).and_return(nil)
        allow(resource).to receive(:[]).with(:name).and_return('opnsense01')
        provider.resource = resource
        provider.fail_on_create!
        expect(PuppetX::Opn::ServiceReconfigure[:test_group])
          .to receive(:mark_error).with('opnsense01')
        expect { provider.create }.to raise_error(Puppet::Error, %r{create failed})
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
