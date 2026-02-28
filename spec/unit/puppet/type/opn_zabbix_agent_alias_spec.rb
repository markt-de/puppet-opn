# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_zabbix_agent_alias) do
  let(:type_name) { :opn_zabbix_agent_alias }
  let(:title) { 'ping@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips key during comparison' do
      is_config = { 'key' => 'x', 'sourceKey' => 'icmpping' }
      should_config = { 'key' => 'y', 'sourceKey' => 'icmpping' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
