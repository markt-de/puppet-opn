# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_firewall_alias).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall aliases via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :firewall_alias

  # Delegates reconfigure to ServiceReconfigure after all opn_firewall_alias
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:firewall_alias].run
  end

  # Fetches all firewall aliases from all configured OPNsense devices.
  # Used by Puppet to pre-populate the resource catalog.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client = api_client(device_name)
      response = client.post('firewall/alias/search_item', {})
      rows = response['rows'] || []

      rows.each do |alias_data|
        alias_name = alias_data['name']
        next if alias_name.nil? || alias_name.empty?

        resource_name = "#{alias_name}@#{device_name}"

        # Build config hash from API data, excluding internal fields
        config = alias_data.reject { |k, _| k == 'uuid' }

        instances << new(
          ensure: :present,
          name:   resource_name,
          device: device_name,
          uuid:   alias_data['uuid'],
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_firewall_alias: failed to fetch aliases from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client     = api_client
    alias_name = resource_alias_name
    config     = (resource[:config] || {}).dup
    config['name'] = alias_name

    result = client.post('firewall/alias/add_item', { 'alias' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_firewall_alias: failed to create '#{alias_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client     = api_client
    uuid       = @property_hash[:uuid]
    alias_name = resource_alias_name

    result = client.post("firewall/alias/del_item/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_firewall_alias: failed to delete '#{alias_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  # Applies pending config changes to OPNsense.
  # reconfigure is NOT called here – it is deferred to post_resource_eval.
  def flush
    return unless @pending_config

    client     = api_client
    uuid       = @property_hash[:uuid]
    alias_name = resource_alias_name
    config     = @pending_config.dup
    config['name'] = alias_name

    result = client.post("firewall/alias/set_item/#{uuid}", { 'alias' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_alias: failed to update '#{alias_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  # Extracts the plain alias name (before the '@') from the resource title.
  def resource_alias_name
    resource[:name].split('@', 2).first
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:firewall_alias].mark(device, client)
  end
end
