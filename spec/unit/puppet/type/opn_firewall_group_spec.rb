# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_firewall_group) do
  let(:type_name) { :opn_firewall_group }
  let(:title) { 'dmz@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }
    let(:resource) { type_class.new(name: title, config: should_config) }
    let(:config_property) { resource.property(:config) }

    it 'returns true when is-hash is a superset of should-hash (case-sensitive)' do
      is_config = { 'key' => 'val', 'extra' => 'x' }
      should_config = { 'key' => 'val' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
