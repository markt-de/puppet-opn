# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'

Puppet::Type.type(:opn_group).provide(:opnsense_api) do
  desc 'Manages OPNsense local groups via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Fetches all local groups from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('auth/group/search', {})
      rows     = response['rows'] || []

      rows.each do |group_data|
        group_name = group_data['name']
        next if group_name.nil? || group_name.empty?

        resource_name = "#{group_name}@#{device_name}"
        config = group_data.reject { |k, _| k == 'uuid' }

        instances << new(
          ensure: :present,
          name:   resource_name,
          device: device_name,
          uuid:   group_data['uuid'],
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_group: failed to fetch groups from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client     = api_client
    group_name = resource_item_name
    config     = (resource[:config] || {}).dup
    config['name'] = group_name

    result = client.post('auth/group/add', { 'group' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error, "opn_group: failed to create '#{group_name}': #{result.inspect}"
  end

  def destroy
    client     = api_client
    uuid       = @property_hash[:uuid]
    group_name = resource_item_name

    result = client.post("auth/group/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_group: failed to delete '#{group_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    @property_hash.clear
  end

  # Applies pending config changes to OPNsense.
  def flush
    return unless @pending_config

    client     = api_client
    uuid       = @property_hash[:uuid]
    group_name = resource_item_name
    config     = @pending_config.dup
    config['name'] = group_name

    result = client.post("auth/group/set/#{uuid}", { 'group' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_group: failed to update '#{group_name}' (uuid: #{uuid}): #{result.inspect}"
  end
end
