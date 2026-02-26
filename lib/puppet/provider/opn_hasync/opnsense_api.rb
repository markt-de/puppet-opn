# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_hasync).provide(:opnsense_api) do
  desc 'Manages OPNsense HA sync settings via the REST API.'

  @devices_to_reconfigure = {}

  def self.devices_to_reconfigure
    @devices_to_reconfigure
  end

  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      begin
        result = client.post('core/hasync/reconfigure', {})
        status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
        if status == 'ok'
          Puppet.notice("opn_hasync: reconfigure on '#{device_name}' completed")
        else
          Puppet.warning(
            "opn_hasync: reconfigure on '#{device_name}' returned unexpected status: #{result.inspect}",
          )
        end
      rescue Puppet::Error => e
        Puppet.err("opn_hasync: reconfigure on '#{device_name}' failed: #{e.message}")
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
        response = client.get('core/hasync/get')
        data     = response['hasync'] || {}

        config = normalize_config(data)

        instances << new(
          ensure: :present,
          name:   device_name,
          config: config,
        )
      rescue Puppet::Error => e
        Puppet.warning("opn_hasync: failed to fetch from '#{device_name}': #{e.message}")
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

  def self.normalize_config(obj)
    return obj unless obj.is_a?(Hash)
    return normalize_selection(obj) if selection_hash?(obj)

    obj.transform_values { |v| normalize_config(v) }
  end

  def self.selection_hash?(hash)
    hash.is_a?(Hash) &&
      !hash.empty? &&
      hash.values.all? { |v| v.is_a?(Hash) && v.key?('value') && v.key?('selected') }
  end

  def self.normalize_selection(hash)
    hash.select { |_k, v| v['selected'].to_i == 1 }.keys.join(',')
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    apply_config(resource[:config] || {})
  end

  def destroy
    client = api_client
    save_settings(client, {})
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

    apply_config(@pending_config)
  end

  private

  def api_client
    self.class.api_client(resource[:name])
  end

  def save_settings(client, config)
    result = client.post('core/hasync/set', { 'hasync' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_hasync: failed to save settings for '#{resource[:name]}': #{result.inspect}"
    end
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  def mark_reconfigure(client)
    self.class.devices_to_reconfigure[resource[:name]] ||= client
  end
end
