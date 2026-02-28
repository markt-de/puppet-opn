# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_plugin) do
  let(:type_name) { :opn_plugin }
  let(:title) { 'os-haproxy@fw01' }

  include_examples 'opn type with device parameter'
  include_examples 'opn type without config property'
end
