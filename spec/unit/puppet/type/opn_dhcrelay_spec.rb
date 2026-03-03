# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_dhcrelay) do
  let(:type_name) { :opn_dhcrelay }
  let(:title) { 'LAN IPv4 Relay@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'compares all keys without skipping' do
      is_config = { 'interface' => 'lan', 'enabled' => '1' }
      should_config = { 'interface' => 'lan', 'enabled' => '1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects differences in any key' do
      is_config = { 'interface' => 'lan', 'enabled' => '0' }
      should_config = { 'interface' => 'lan', 'enabled' => '1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
