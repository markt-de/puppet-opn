# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_acmeclient_action) do
  let(:type_name) { :opn_acmeclient_action }
  let(:title) { 'restart_haproxy@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name during comparison' do
      is_config = { 'name' => 'different', 'type' => 'configd_generic' }
      should_config = { 'name' => 'original', 'type' => 'configd_generic' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'type' => 'other_command' }
      should_config = { 'type' => 'configd_generic' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
