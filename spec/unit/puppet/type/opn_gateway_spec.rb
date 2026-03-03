# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_gateway) do
  let(:type_name) { :opn_gateway }
  let(:title) { 'WAN_GW@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name field during comparison' do
      is_config = { 'interface' => 'wan', 'gateway' => '192.168.1.1' }
      should_config = { 'interface' => 'wan', 'gateway' => '192.168.1.1', 'name' => 'WAN_GW' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
