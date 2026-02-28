# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_haproxy_lua) do
  let(:type_name) { :opn_haproxy_lua }
  let(:title) { 'my_lua@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name key during comparison' do
      is_config = { 'name' => 'different', 'expression' => 'ssl_fc' }
      should_config = { 'name' => 'original', 'expression' => 'ssl_fc' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
