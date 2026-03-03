# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_gateway).provide(:opnsense_api) do
  desc 'Manages OPNsense gateways via the REST API.'

  # Tracks devices that need a reconfigure after gateway changes.
  # Cleared after post_resource_eval runs the reconfigure call.
  @devices_to_reconfigure = {}

  class << self
    attr_reader :devices_to_reconfigure
  end

  # Called once after all opn_gateway resources have been evaluated.
  # Triggers routing/settings/reconfigure for each device that had changes.
  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      result = client.post('routing/settings/reconfigure', {})
      status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
      if status == 'ok'
        Puppet.notice("opn_gateway: reconfigure on '#{device_name}' completed")
      else
        Puppet.warning(
          "opn_gateway: reconfigure on '#{device_name}' returned unexpected status: #{result.inspect}",
        )
      end
    rescue Puppet::Error => e
      Puppet.err("opn_gateway: reconfigure on '#{device_name}' failed: #{e.message}")
    end
    @devices_to_reconfigure.clear
  end

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fields added by the searchGateway enrichment that are NOT part of the
  # Gateways model. These are runtime/display fields and must be stripped
  # from the config hash to avoid false-positive idempotency changes.
  def self.search_volatile_fields
    %w[
      virtual upstream interface_descr status delay stddev loss
      label_class if attribute dynamic defunct is_loopback gateway_interface
    ]
  end

  # UUID format regex — only MVC model gateways have real UUIDs.
  # Virtual/dynamic and legacy gateways get their name as UUID by the search
  # API and must be skipped (they are auto-managed by OPNsense).
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # Fetches all gateways from every configured OPNsense device.
  # The searchGateway API returns enriched data including virtual/dynamic
  # gateways — we filter to only manage MVC model gateways with real UUIDs.
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('routing/settings/searchGateway', {})
      rows     = response['rows'] || []

      rows.each do |row|
        # Skip virtual/dynamic/legacy gateways that lack a real UUID
        next unless row['uuid'].to_s.match?(UUID_PATTERN)

        gw_name = row['name'].to_s
        next if gw_name.empty?

        config = normalize_config(row)

        instances << new(
          ensure: :present,
          name:   "#{gw_name}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_gateway: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  # Normalizes the raw search result into a clean config hash:
  # 1. Restores model 'defaultgw' from the 'upstream' enrichment field
  #    (searchGateway overwrites 'defaultgw' with the active default status)
  # 2. Removes volatile enrichment fields and current_* computed fields
  # 3. Converts boolean values to '0'/'1' strings (searchGateway converts
  #    some BooleanField values from '0'/'1' to true/false)
  def self.normalize_config(row)
    config = row.dup

    # Restore model 'defaultgw' from 'upstream' before removing enrichment
    config['defaultgw'] = config.delete('upstream') if config.key?('upstream')

    # Remove uuid and all enrichment-only fields
    config.delete('uuid')
    search_volatile_fields.each { |f| config.delete(f) }
    config.reject! { |k, _| k.start_with?('current_') }

    # Normalize booleans to strings (searchGateway converts some to true/false)
    config.transform_values! do |v|
      case v
      when true then '1'
      when false then '0'
      else v
      end
    end

    config
  end

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

  # Creates a new gateway via the API.
  # Injects the gateway name from the resource title into the config.
  def create
    client  = api_client
    gw_name = resource_item_name
    config  = (resource[:config] || {}).dup
    config['name'] = gw_name

    result = client.post('routing/settings/addGateway', { 'gateway_item' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_gateway: failed to create '#{gw_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client  = api_client
    uuid    = @property_hash[:uuid]
    gw_name = resource_item_name

    result = client.post("routing/settings/delGateway/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_gateway: failed to delete '#{gw_name}' (uuid: #{uuid}): #{result.inspect}"
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

  # Updates an existing gateway via the API.
  # Note: OPNsense does not allow renaming gateways after creation, but the
  # name field must still be included in the payload (model validation).
  def flush
    return unless @pending_config

    client  = api_client
    uuid    = @property_hash[:uuid]
    gw_name = resource_item_name
    config  = @pending_config.dup
    config['name'] = gw_name

    result = client.post("routing/settings/setGateway/#{uuid}", { 'gateway_item' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_gateway: failed to update '#{gw_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  def resource_item_name
    resource[:name].split('@', 2).first
  end

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    self.class.devices_to_reconfigure[device] ||= client
  end
end
