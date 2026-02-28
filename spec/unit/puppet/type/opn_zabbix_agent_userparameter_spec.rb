# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_zabbix_agent_userparameter) do
  let(:type_name) { :opn_zabbix_agent_userparameter }
  let(:title) { 'custom.uptime@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips key during comparison' do
      is_config = { 'key' => 'x', 'command' => '/usr/bin/uptime' }
      should_config = { 'key' => 'y', 'command' => '/usr/bin/uptime' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
