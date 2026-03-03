# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_route) do
  let(:type_name) { :opn_route }
  let(:title) { 'Server network@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips descr field during comparison' do
      is_config = { 'network' => '10.0.0.0/24', 'gateway' => 'Wan_DHCP' }
      should_config = { 'network' => '10.0.0.0/24', 'gateway' => 'Wan_DHCP', 'descr' => 'Server network' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
