# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_acmeclient_account) do
  let(:type_name) { :opn_acmeclient_account }
  let(:title) { 'le-account@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name during comparison' do
      is_config = { 'name' => 'different', 'ca' => 'letsencrypt' }
      should_config = { 'name' => 'original', 'ca' => 'letsencrypt' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips volatile fields during comparison' do
      is_config = { 'ca' => 'letsencrypt', 'key' => 'secret', 'statusCode' => '200', 'statusLastUpdate' => '2024-01-01' }
      should_config = { 'ca' => 'letsencrypt', 'key' => 'other', 'statusCode' => '0', 'statusLastUpdate' => '' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'ca' => 'letsencrypt' }
      should_config = { 'ca' => 'buypass' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
