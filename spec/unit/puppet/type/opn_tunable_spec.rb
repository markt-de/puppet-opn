# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_tunable) do
  let(:type_name) { :opn_tunable }
  let(:title) { 'kern.maxproc@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips volatile fields (tunable, default_value, type) during comparison' do
      is_config = { 'value' => '4096' }
      should_config = { 'value' => '4096', 'tunable' => 'kern.maxproc', 'default_value' => '1000', 'type' => 'integer' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
