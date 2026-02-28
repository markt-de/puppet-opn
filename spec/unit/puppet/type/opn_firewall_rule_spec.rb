# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_firewall_rule) do
  let(:type_name) { :opn_firewall_rule }
  let(:title) { 'Allow HTTP@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }
    let(:resource) { type_class.new(name: title, config: should_config) }
    let(:config_property) { resource.property(:config) }

    it 'returns true when values differ only in case (case-insensitive)' do
      is_config = { 'protocol' => 'TCP' }
      should_config = { 'protocol' => 'tcp' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
