# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_firewall_alias).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall aliases via the REST API.'

  # Tracks devices that have pending alias changes during this Puppet run.
  # Maps device_name => ApiClient instance.
  # Populated by create/destroy/flush; consumed by post_resource_eval.
  @devices_to_reconfigure = {}

  class << self
    attr_reader :devices_to_reconfigure
  end

  # Called by Puppet once after ALL opn_firewall_alias resources have been
  # evaluated in this catalog run. Triggers exactly one reconfigure API call
  # per device that had at least one alias change, then clears the tracking hash.
  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      result = client.post('firewall/alias/reconfigure', {})
      status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
      if status == 'ok'
        Puppet.notice("opn_firewall_alias: reconfigure of '#{device_name}' completed")
      else
        Puppet.warning(
          "opn_firewall_alias: reconfigure of '#{device_name}' returned unexpected status: #{result.inspect}",
        )
      end
    rescue Puppet::Error => e
      Puppet.err("opn_firewall_alias: reconfigure of '#{device_name}' failed: #{e.message}")
    end
    @devices_to_reconfigure.clear
  end

  # Returns an ApiClient instance for the given device.
  #
  # @param device_name [String]
  # @return [PuppetX::Opn::ApiClient]
  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
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

  # Matches provider instances to Puppet resources.
  def self.prefetch(resources)
    all_instances = instances
    resources.each do |name, resource|
      provider = all_instances.find { |inst| inst.name == name }
      resource.provider = provider if provider
    end
  end

  def exists?
    @property_hash[:ensure] == :present
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

  def config
    @property_hash[:config]
  end

  def config=(value)
    @pending_config = value
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

  # Returns an ApiClient for the current resource's device.
  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  # Extracts the plain alias name (before the '@') from the resource title.
  def resource_alias_name
    resource[:name].split('@', 2).first
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    self.class.devices_to_reconfigure[device] ||= client
  end
end
