# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_syslog) do
  let(:type_name) { :opn_syslog }
  let(:title) { 'Central syslog@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'transport' => 'udp4' }
      should_config = { 'description' => 'z', 'transport' => 'udp4' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
