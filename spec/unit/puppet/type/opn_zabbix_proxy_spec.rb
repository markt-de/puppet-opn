# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_zabbix_proxy) do
  let(:type_name) { :opn_zabbix_proxy }
  let(:title) { 'fw01' }

  include_examples 'opn singleton type'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'returns true when should is a subset of is (partial match)' do
      is_config = { 'enabled' => '1', 'server' => 'zabbix.example.com' }
      should_config = { 'enabled' => '1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
