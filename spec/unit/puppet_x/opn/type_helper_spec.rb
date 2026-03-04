# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/type_helper'

describe PuppetX::Opn::TypeHelper do
  # Creates an anonymous Puppet type with the given setup parameters.
  def create_test_type(type_name, **setup_opts)
    Puppet::Type.newtype(type_name) do
      desc 'Test type for TypeHelper spec'
      PuppetX::Opn::TypeHelper.setup(self, **setup_opts)
    end
  end

  # --- Standard type with device parameter ---

  context 'standard type with device parameter' do
    let(:type_class) do
      create_test_type(:opn_th_test_standard,
        name_desc: 'Resource title in name@device format',
        config_desc: 'A hash of config options')
    end

    after(:each) do
      Puppet::Type.rmtype(:opn_th_test_standard)
    end

    it 'has ensurable with default :present' do
      res = type_class.new(name: 'test@opnsense01')
      expect(res[:ensure]).to eq(:present)
    end

    it 'has :name as namevar' do
      expect(type_class.key_attributes).to eq([:name])
    end

    it 'extracts device from the title' do
      res = type_class.new(name: 'myitem@opnsense01')
      expect(res[:device]).to eq('opnsense01')
    end

    it 'sets device to "default" when no @ in title' do
      res = type_class.new(name: 'simple')
      expect(res[:device]).to eq('default')
    end

    it 'rejects empty name' do
      expect { type_class.new(name: '') }.to raise_error(Puppet::Error)
    end

    it 'accepts Hash as config' do
      res = type_class.new(name: 'test@dev', config: { 'k' => 'v' })
      expect(res[:config]).to eq('k' => 'v')
    end

    it 'rejects String as config' do
      expect { type_class.new(name: 'test@dev', config: 'nope') }
        .to raise_error(Puppet::Error, %r{must be a Hash})
    end
  end

  # --- Singleton type (no device parameter) ---

  context 'singleton type' do
    let(:type_class) do
      create_test_type(:opn_th_test_singleton,
        name_desc: 'OPNsense device name',
        config_desc: 'Settings hash',
        singleton: true,
        insync_mode: :deep_match)
    end

    after(:each) do
      Puppet::Type.rmtype(:opn_th_test_singleton)
    end

    it 'has no device parameter' do
      res = type_class.new(name: 'opnsense01')
      expect { res[:device] }.to raise_error(Puppet::Error)
    end

    it 'sets name directly as namevar' do
      res = type_class.new(name: 'opnsense01')
      expect(res[:name]).to eq('opnsense01')
    end
  end

  # --- Type without config property (like opn_plugin) ---

  context 'type without config property' do
    let(:type_class) do
      create_test_type(:opn_th_test_no_config,
        name_desc: 'Plugin name@device')
    end

    after(:each) do
      Puppet::Type.rmtype(:opn_th_test_no_config)
    end

    it 'has no config property' do
      res = type_class.new(name: 'os-haproxy@opnsense01')
      expect(res.property(:config)).to be_nil
    end
  end

  # --- insync? modes ---

  describe 'insync? modes' do
    # Helper: creates a resource and returns its config property.
    def config_property(type_class, should_config)
      res = type_class.new(name: 'test@dev', config: should_config)
      res.property(:config)
    end

    context ':simple — reject skip_fields + volatile_fields' do
      let(:type_class) do
        create_test_type(:opn_th_test_simple,
          name_desc: 'test', config_desc: 'test',
          skip_fields: ['name'],
          volatile_fields: ['statusCode'])
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_simple) }

      it 'ignores skip_fields and volatile_fields during comparison' do
        prop = config_property(type_class,
          { 'name' => 'x', 'statusCode' => '200', 'mode' => 'http' })
        is_val = { 'name' => 'DIFFERENT', 'statusCode' => '500',
                   'mode' => 'http', 'extra' => 'ignored' }
        expect(prop.insync?(is_val)).to be true
      end

      it 'detects mismatch in non-skipped fields' do
        prop = config_property(type_class, { 'mode' => 'http' })
        is_val = { 'mode' => 'tcp' }
        expect(prop.insync?(is_val)).to be false
      end

      it 'compares values as strings' do
        prop = config_property(type_class, { 'enabled' => '1' })
        is_val = { 'enabled' => 1 }
        expect(prop.insync?(is_val)).to be true
      end

      it 'returns false when is is not a Hash' do
        prop = config_property(type_class, { 'k' => 'v' })
        expect(prop.insync?(nil)).to be false
        expect(prop.insync?('string')).to be false
      end
    end

    context ':simple — with password_fields' do
      let(:type_class) do
        create_test_type(:opn_th_test_pw,
          name_desc: 'test', config_desc: 'test',
          skip_fields: ['name'],
          password_fields: ['password'])
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_pw) }

      it 'skips password fields (always in-sync)' do
        prop = config_property(type_class,
          { 'name' => 'x', 'password' => 'new_pass', 'mode' => 'http' })
        is_val = { 'name' => 'x', 'password' => 'DIFFERENT', 'mode' => 'http' }
        expect(prop.insync?(is_val)).to be true
      end
    end

    context ':simple — with skip_prefixes' do
      let(:type_class) do
        create_test_type(:opn_th_test_prefix,
          name_desc: 'test', config_desc: 'test',
          skip_fields: ['serial', 'caref', 'text'],
          skip_prefixes: ['revoked_reason_'])
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_prefix) }

      it 'skips fields starting with prefix' do
        prop = config_property(type_class,
          { 'serial' => '1', 'revoked_reason_0' => 'old',
            'method' => 'internal' })
        is_val = { 'serial' => '99', 'revoked_reason_0' => 'DIFFERENT',
                   'method' => 'internal' }
        expect(prop.insync?(is_val)).to be true
      end
    end

    context ':deep_match — recursive comparison' do
      let(:type_class) do
        create_test_type(:opn_th_test_deep,
          name_desc: 'test', config_desc: 'test',
          singleton: true,
          insync_mode: :deep_match)
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_deep) }

      it 'compares nested hashes recursively' do
        prop = config_property(type_class,
          { 'section' => { 'enabled' => '1' } })
        is_val = { 'section' => { 'enabled' => '1', 'extra' => '2' },
                   'other' => 'ignored' }
        expect(prop.insync?(is_val)).to be true
      end

      it 'detects mismatch in nested structure' do
        prop = config_property(type_class,
          { 'section' => { 'enabled' => '1' } })
        is_val = { 'section' => { 'enabled' => '0' } }
        expect(prop.insync?(is_val)).to be false
      end

      it 'returns false when is is not a Hash' do
        prop = config_property(type_class, { 'k' => 'v' })
        expect(prop.insync?(nil)).to be false
      end
    end

    context ':deep_match — with password_fields' do
      let(:type_class) do
        create_test_type(:opn_th_test_deep_pw,
          name_desc: 'test', config_desc: 'test',
          singleton: true,
          insync_mode: :deep_match,
          password_fields: ['password'])
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_deep_pw) }

      it 'skips password fields in deep match' do
        prop = config_property(type_class,
          { 'password' => 'secret', 'mode' => 'active' })
        is_val = { 'password' => 'DIFFERENT', 'mode' => 'active' }
        expect(prop.insync?(is_val)).to be true
      end
    end

    context ':casecmp — case-insensitive comparison' do
      let(:type_class) do
        create_test_type(:opn_th_test_casecmp,
          name_desc: 'test', config_desc: 'test',
          insync_mode: :casecmp)
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_casecmp) }

      it 'compares case-insensitively' do
        prop = config_property(type_class, { 'action' => 'PASS' })
        is_val = { 'action' => 'pass' }
        expect(prop.insync?(is_val)).to be true
      end

      it 'returns false when is is not a Hash' do
        prop = config_property(type_class, { 'k' => 'v' })
        expect(prop.insync?(nil)).to be false
      end
    end
  end

  # --- Autorequires ---

  describe 'autorequires' do
    context 'simple field (single)' do
      let(:type_class) do
        create_test_type(:opn_th_test_ar_single,
          name_desc: 'test', config_desc: 'test',
          autorequires: {
            opn_ipsec_connection: { field: 'connection' },
          })
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_ar_single) }

      it 'registers autorequire for the field' do
        # eachautorequire is yield-based, wrap with enum_for to collect entries
        expect(type_class.enum_for(:eachautorequire).to_a.size).to eq(1)
      end
    end

    context 'comma-separated field (multiple)' do
      let(:type_class) do
        create_test_type(:opn_th_test_ar_multi,
          name_desc: 'test', config_desc: 'test',
          autorequires: {
            opn_haproxy_server: { field: 'linkedServers', multiple: true },
          })
      end

      after(:each) { Puppet::Type.rmtype(:opn_th_test_ar_multi) }

      it 'registers autorequire for comma-separated fields' do
        # eachautorequire is yield-based, wrap with enum_for to collect entries
        expect(type_class.enum_for(:eachautorequire).to_a.size).to eq(1)
      end
    end
  end

  # --- is_to_s / should_to_s ---

  describe 'is_to_s / should_to_s' do
    let(:type_class) do
      create_test_type(:opn_th_test_tos,
        name_desc: 'test', config_desc: 'test')
    end

    after(:each) { Puppet::Type.rmtype(:opn_th_test_tos) }

    it 'returns .inspect for hashes' do
      res = type_class.new(name: 'test@dev', config: { 'k' => 'v' })
      prop = res.property(:config)
      expect(prop.is_to_s({ 'a' => '1' })).to eq({ 'a' => '1' }.inspect)
      expect(prop.should_to_s({ 'b' => '2' })).to eq({ 'b' => '2' }.inspect)
    end
  end
end
