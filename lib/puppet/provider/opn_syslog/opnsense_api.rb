# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_syslog).provide(:opnsense_api) do
  desc 'Manages OPNsense syslog destinations via the REST API.'

  @devices_to_reconfigure = {}

  def self.devices_to_reconfigure
    @devices_to_reconfigure
  end

  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      begin
        result = client.post('syslog/service/reconfigure', {})
        status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
        if status == 'ok'
          Puppet.notice("opn_syslog: reconfigure on '#{device_name}' completed")
        else
          Puppet.warning(
            "opn_syslog: reconfigure on '#{device_name}' returned unexpected status: #{result.inspect}",
          )
        end
      rescue Puppet::Error => e
        Puppet.err("opn_syslog: reconfigure on '#{device_name}' failed: #{e.message}")
      end
    end
    @devices_to_reconfigure.clear
  end

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
        client   = api_client(device_name)
        response = client.post('syslog/settings/search_destinations', {})
        rows     = response['rows'] || []

        rows.each do |row|
          description = row['description'].to_s
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
        Puppet.warning("opn_syslog: failed to fetch from '#{device_name}': #{e.message}")
      end
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

  def create
    client      = api_client
    description = resource_item_name
    config      = (resource[:config] || {}).dup
    config['description'] = description

    result = client.post('syslog/settings/add_destination', { 'destination' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_syslog: failed to create '#{description}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_item_name

    result = client.post("syslog/settings/del_destination/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_syslog: failed to delete '#{description}' (uuid: #{uuid}): #{result.inspect}"
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

  def flush
    return unless @pending_config

    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_item_name
    config      = @pending_config.dup
    config['description'] = description

    result = client.post("syslog/settings/set_destination/#{uuid}", { 'destination' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_syslog: failed to update '#{description}' (uuid: #{uuid}): #{result.inspect}"
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
