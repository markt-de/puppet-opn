# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_ipsec_keypair) do
  let(:type_name) { :opn_ipsec_keypair }
  let(:title) { 'my-keypair@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name during comparison' do
      is_config = { 'name' => 'different', 'keyType' => 'rsa' }
      should_config = { 'name' => 'original', 'keyType' => 'rsa' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips volatile fields during comparison' do
      is_config = { 'keyType' => 'rsa', 'keyFingerprint' => 'abc', 'keySize' => '2048' }
      should_config = { 'keyType' => 'rsa', 'keyFingerprint' => 'xyz', 'keySize' => '4096' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips privateKey during comparison' do
      is_config = { 'keyType' => 'rsa', 'privateKey' => 'stored-key' }
      should_config = { 'keyType' => 'rsa', 'privateKey' => 'new-key' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'keyType' => 'rsa' }
      should_config = { 'keyType' => 'ecdsa' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
