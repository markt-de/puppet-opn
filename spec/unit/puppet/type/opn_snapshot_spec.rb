# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_snapshot) do
  let(:type_name) { :opn_snapshot }
  let(:title) { 'pre-upgrade@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips readonly fields during comparison' do
      is_config = { 'note' => 'test', 'name' => 'x', 'active' => '1', 'size' => '100M' }
      should_config = { 'note' => 'test', 'name' => 'y', 'active' => '0', 'size' => '200M' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end

  describe 'active property' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'accepts :true' do
      resource = type_class.new(name: title, active: :true, config: { 'note' => 'test' })
      expect(resource[:active]).to eq(:true)
    end

    it 'accepts :false' do
      resource = type_class.new(name: title, active: :false, config: { 'note' => 'test' })
      expect(resource[:active]).to eq(:false)
    end
  end
end
