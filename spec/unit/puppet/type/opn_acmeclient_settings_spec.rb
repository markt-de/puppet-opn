# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:opn_acmeclient_settings) do
  let(:type_name) { :opn_acmeclient_settings }
  let(:title) { 'fw01' }

  include_examples 'opn singleton type'
  include_examples 'opn type with config property'

  describe 'config insync?' do
    let(:type_class) { Puppet::Type.type(type_name) }

    it 'returns true when should is a subset of is (flat match)' do
      is_config = { 'environment' => 'stg', 'logLevel' => 'normal', 'autoRenewal' => '1' }
      should_config = { 'environment' => 'stg' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be true
    end

    it 'returns false when a value differs' do
      is_config = { 'environment' => 'stg' }
      should_config = { 'environment' => 'prd' }
      resource = type_class.new(name: title, config: should_config)
      config_property = resource.property(:config)
      expect(config_property.insync?(is_config)).to be false
    end
  end

  describe 'autorequires' do
    it 'autorequires the UpdateCron cron job' do
      catalog = Puppet::Resource::Catalog.new
      settings = Puppet::Type.type(:opn_acmeclient_settings).new(
        name: 'fw01',
        config: { 'UpdateCron' => 'ACME renew' },
      )
      cron = Puppet::Type.type(:opn_cron).new(name: 'ACME renew@fw01')
      catalog.add_resource(settings, cron)
      reqs = settings.autorequire
      req_sources = reqs.map { |r| r.source.to_s }
      expect(req_sources).to include('Opn_cron[ACME renew@fw01]')
    end
  end
end
