# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_ipsec_presharedkey) do
  let(:type_name) { :opn_ipsec_presharedkey }
  let(:title) { 'remote-peer@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips ident during comparison' do
      is_config = { 'ident' => 'x', 'keyType' => 'PSK' }
      should_config = { 'ident' => 'z', 'keyType' => 'PSK' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips Key during comparison' do
      is_config = { 'keyType' => 'PSK', 'Key' => 'stored-secret' }
      should_config = { 'keyType' => 'PSK', 'Key' => 'new-secret' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'keyType' => 'PSK' }
      should_config = { 'keyType' => 'EAP' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
