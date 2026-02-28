# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_trust_cert) do
  let(:type_name) { :opn_trust_cert }
  let(:title) { 'web.example.com@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips descr during comparison' do
      is_config = { 'descr' => 'x', 'caref' => 'ref1' }
      should_config = { 'descr' => 'y', 'caref' => 'ref1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'descr' => 'x', 'caref' => 'ref1' }
      should_config = { 'descr' => 'x', 'caref' => 'other' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
