# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_ipsec_pool) do
  let(:type_name) { :opn_ipsec_pool }
  let(:title) { 'vpn-pool@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name during comparison' do
      is_config = { 'name' => 'x', 'addrs' => '10.0.0.0/24' }
      should_config = { 'name' => 'z', 'addrs' => '10.0.0.0/24' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
