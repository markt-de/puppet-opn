# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_ipsec_connection) do
  let(:type_name) { :opn_ipsec_connection }
  let(:title) { 'site-to-site@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'version' => '2' }
      should_config = { 'description' => 'z', 'version' => '2' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'skips volatile fields during comparison' do
      is_config = { 'version' => '2', 'local_ts' => '10.0.0.0/24', 'remote_ts' => '10.0.1.0/24' }
      should_config = { 'version' => '2', 'local_ts' => '', 'remote_ts' => '' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'detects real differences' do
      is_config = { 'version' => '2' }
      should_config = { 'version' => '1' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end
end
