# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_ipsec_vti) do
  let(:type_name) { :opn_ipsec_vti }
  let(:title) { 'tunnel-to-remote@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'reqid' => '100' }
      should_config = { 'description' => 'z', 'reqid' => '100' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips volatile fields during comparison' do
      is_config = { 'reqid' => '100', 'origin' => 'new' }
      should_config = { 'reqid' => '100', 'origin' => 'legacy' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'reqid' => '100' }
      should_config = { 'reqid' => '200' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
