# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_openvpn_statickey) do
  let(:type_name) { :opn_openvpn_statickey }
  let(:title) { 'my-tls-auth-key@opnsense01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'skips description during comparison' do
      is_config = { 'description' => 'x', 'mode' => 'auth' }
      should_config = { 'description' => 'z', 'mode' => 'auth' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end
  end
end
