# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_haproxy_settings) do
  let(:type_name) { :opn_haproxy_settings }
  let(:title) { 'fw01' }

  include_examples 'opn singleton type'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'returns true when should is a subset of is (deep match)' do
      is_config = { 'general' => { 'enabled' => '1', 'tuning' => { 'x' => '1' } } }
      should_config = { 'general' => { 'enabled' => '1' } }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'returns false when a value differs' do
      is_config = { 'general' => { 'enabled' => '0' } }
      should_config = { 'general' => { 'enabled' => '1' } }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
