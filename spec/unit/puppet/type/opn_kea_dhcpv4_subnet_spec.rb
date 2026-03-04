# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_kea_dhcpv4_subnet) do
  let(:type_name) { :opn_kea_dhcpv4_subnet }
  let(:title) { '192.168.1.0/24@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'returns true when should is a subset of is (deep match)' do
      is_config = { 'subnet' => '192.168.1.0/24', 'description' => 'LAN', 'pools' => '192.168.1.100 - 192.168.1.200' }
      should_config = { 'description' => 'LAN' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'returns false when a value differs' do
      is_config = { 'subnet' => '192.168.1.0/24', 'description' => 'LAN' }
      should_config = { 'description' => 'WAN' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
