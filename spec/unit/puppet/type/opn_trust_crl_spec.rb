# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_trust_crl) do
  let(:type_name) { :opn_trust_crl }
  let(:title) { 'My Root CA@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips serial and caref during comparison' do
      is_config = { 'descr' => 'CRL', 'serial' => '1', 'caref' => 'abc', 'lifetime' => '9999' }
      should_config = { 'descr' => 'CRL', 'serial' => '5', 'caref' => 'xyz', 'lifetime' => '9999' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips keys starting with revoked_reason_ during comparison' do
      is_config = { 'descr' => 'CRL', 'revoked_reason_abc' => '1' }
      should_config = { 'descr' => 'CRL', 'revoked_reason_abc' => '2' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'returns false when a non-skipped value differs' do
      is_config = { 'descr' => 'CRL', 'lifetime' => '100' }
      should_config = { 'descr' => 'CRL', 'lifetime' => '200' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
