# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_route).provide(:opnsense_api) do
  desc 'Manages OPNsense static routes via the REST API.'

  # Tracks devices that need a reconfigure after route changes.
  # Cleared after post_resource_eval runs the reconfigure call.
  @devices_to_reconfigure = {}

  class << self
    attr_reader :devices_to_reconfigure
  end

  # Called once after all opn_route resources have been evaluated.
  # Triggers routes/routes/reconfigure for each device that had changes.
  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      result = client.post('routes/routes/reconfigure', {})
      status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
      if status == 'ok'
        Puppet.notice("opn_route: reconfigure on '#{device_name}' completed")
      else
        Puppet.warning(
          "opn_route: reconfigure on '#{device_name}' returned unexpected status: #{result.inspect}",
        )
      end
    rescue Puppet::Error => e
      Puppet.err("opn_route: reconfigure on '#{device_name}' failed: #{e.message}")
    end
    @devices_to_reconfigure.clear
  end

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches all static routes from every configured OPNsense device.
  # The API field 'descr' is used as the human-readable identifier.
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('routes/routes/searchroute', {})
      rows     = response['rows'] || []

      rows.each do |row|
        description = row['descr'].to_s
        next if description.empty?

        instances << new(
          ensure: :present,
          name:   "#{description}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: row.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_route: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
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

  # Creates a new static route via the API.
  # Injects the description from the resource title as 'descr' (OPNsense model field name).
  def create
    client      = api_client
    description = resource_item_name
    config      = (resource[:config] || {}).dup
    config['descr'] = description

    result = client.post('routes/routes/addroute', { 'route' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_route: failed to create '#{description}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_item_name

    result = client.post("routes/routes/delroute/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_route: failed to delete '#{description}' (uuid: #{uuid}): #{result.inspect}"
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

  # Updates an existing static route via the API.
  # Uses 'setroute' (not 'update') — OPNsense core routes follow the standard set pattern.
  def flush
    return unless @pending_config

    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_item_name
    config      = @pending_config.dup
    config['descr'] = description

    result = client.post("routes/routes/setroute/#{uuid}", { 'route' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_route: failed to update '#{description}' (uuid: #{uuid}): #{result.inspect}"
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
