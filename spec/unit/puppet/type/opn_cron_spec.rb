# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_cron) do
  let(:type_name) { :opn_cron }
  let(:title) { 'Daily backup@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'command' => 'y' }
      should_config = { 'description' => 'z', 'command' => 'y' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
