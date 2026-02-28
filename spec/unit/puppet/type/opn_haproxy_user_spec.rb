# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_haproxy_user) do
  let(:type_name) { :opn_haproxy_user }
  let(:title) { 'stats_user@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips name and password during comparison' do
      is_config = { 'name' => 'x', 'password' => '$2y$hash', 'description' => 'Stats' }
      should_config = { 'name' => 'y', 'password' => 'plain', 'description' => 'Stats' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
