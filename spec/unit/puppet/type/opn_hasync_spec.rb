# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_hasync) do
  let(:type_name) { :opn_hasync }
  let(:title) { 'fw01' }

  include_examples 'opn singleton type'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips password during deep comparison' do
      is_config = { 'pfsyncenabled' => '1', 'password' => 'hashed' }
      should_config = { 'pfsyncenabled' => '1', 'password' => 'plain' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'returns false when a non-password value differs' do
      is_config = { 'pfsyncenabled' => '0' }
      should_config = { 'pfsyncenabled' => '1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
