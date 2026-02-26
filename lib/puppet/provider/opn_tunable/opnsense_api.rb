# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_tunable).provide(:opnsense_api) do
  desc 'Manages OPNsense system tunables via the REST API.'

  @devices_to_reconfigure = {}

  def self.devices_to_reconfigure
    @devices_to_reconfigure
  end

  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      begin
        result = client.post('core/tunables/reconfigure', {})
        status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
        if status == 'ok'
          Puppet.notice("opn_tunable: reconfigure on '#{device_name}' completed")
        else
          Puppet.warning(
            "opn_tunable: reconfigure on '#{device_name}' returned unexpected status: #{result.inspect}",
          )
        end
      rescue Puppet::Error => e
        Puppet.err("opn_tunable: reconfigure on '#{device_name}' failed: #{e.message}")
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
        response = client.post('core/tunables/search_item', {})
        rows     = response['rows'] || []

        rows.each do |row|
          tunable = row['tunable'].to_s
          next if tunable.empty?

          instances << new(
            ensure: :present,
            name:   "#{tunable}@#{device_name}",
            device: device_name,
            uuid:   row['uuid'],
            config: row.reject { |k, _| k == 'uuid' },
          )
        end
      rescue Puppet::Error => e
        Puppet.warning("opn_tunable: failed to fetch from '#{device_name}': #{e.message}")
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
    client  = api_client
    tunable = resource_item_name
    config  = (resource[:config] || {}).dup
    config['tunable'] = tunable

    result = client.post('core/tunables/add_item', { 'sysctl' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_tunable: failed to create '#{tunable}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client  = api_client
    uuid    = @property_hash[:uuid]
    tunable = resource_item_name

    result = client.post("core/tunables/del_item/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_tunable: failed to delete '#{tunable}' (uuid: #{uuid}): #{result.inspect}"
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

    client  = api_client
    uuid    = @property_hash[:uuid]
    tunable = resource_item_name
    config  = @pending_config.dup
    config['tunable'] = tunable

    result = client.post("core/tunables/set_item/#{uuid}", { 'sysctl' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_tunable: failed to update '#{tunable}' (uuid: #{uuid}): #{result.inspect}"
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
