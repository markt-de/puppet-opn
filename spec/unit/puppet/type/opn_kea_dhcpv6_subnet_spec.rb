# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_kea_dhcpv6_subnet) do
  let(:type_name) { :opn_kea_dhcpv6_subnet }
  let(:title) { 'fd00::/64@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'returns true when should is a subset of is (deep match)' do
      is_config = { 'subnet' => 'fd00::/64', 'description' => 'LAN v6', 'pools' => 'fd00::100 - fd00::200' }
      should_config = { 'description' => 'LAN v6' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'returns false when a value differs' do
      is_config = { 'subnet' => 'fd00::/64', 'description' => 'LAN v6' }
      should_config = { 'description' => 'WAN v6' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
