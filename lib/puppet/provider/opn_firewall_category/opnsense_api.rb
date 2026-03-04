# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'

Puppet::Type.type(:opn_firewall_category).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall categories via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Fetches all firewall categories from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('firewall/category/search_item', {})
      rows     = response['rows'] || []

      rows.each do |cat_data|
        cat_name = cat_data['name']
        next if cat_name.nil? || cat_name.empty?

        resource_name = "#{cat_name}@#{device_name}"
        config = cat_data.reject { |k, _| k == 'uuid' }

        instances << new(
          ensure: :present,
          name:   resource_name,
          device: device_name,
          uuid:   cat_data['uuid'],
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning(
        "opn_firewall_category: failed to fetch categories from '#{device_name}': #{e.message}",
      )
    end

    instances
  end

  def create
    client   = api_client
    cat_name = resource_item_name
    config   = (resource[:config] || {}).dup
    config['name'] = cat_name

    result = client.post('firewall/category/add_item', { 'category' => config })
    return if result['result'].to_s.strip.downcase == 'saved'

    raise Puppet::Error,
          "opn_firewall_category: failed to create '#{cat_name}': #{result.inspect}"
  end

  def destroy
    client   = api_client
    uuid     = @property_hash[:uuid]
    cat_name = resource_item_name

    result = client.post("firewall/category/del_item/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_firewall_category: failed to delete '#{cat_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    @property_hash.clear
  end

  # Applies pending config changes to OPNsense.
  def flush
    return unless @pending_config

    client   = api_client
    uuid     = @property_hash[:uuid]
    cat_name = resource_item_name
    config   = @pending_config.dup
    config['name'] = cat_name

    result = client.post("firewall/category/set_item/#{uuid}", { 'category' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_firewall_category: failed to update '#{cat_name}' (uuid: #{uuid}): #{result.inspect}"
  end
end
