# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_group).provide(:opnsense_api) do
  desc 'Manages OPNsense local groups via the REST API.'

  # Returns an ApiClient instance for the given device.
  #
  # @param device_name [String]
  # @return [PuppetX::Opn::ApiClient]
  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches all local groups from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
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
    group_name = resource_group_name
    config     = (resource[:config] || {}).dup
    config['name'] = group_name

    result = client.post('auth/group/add', { 'group' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_group: failed to create '#{group_name}': #{result.inspect}"
    end
  end

  def destroy
    client     = api_client
    uuid       = @property_hash[:uuid]
    group_name = resource_group_name

    result = client.post("auth/group/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_group: failed to delete '#{group_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    @property_hash.clear
  end

  def config
    @property_hash[:config]
  end

  def config=(value)
    @pending_config = value
  end

  # Applies pending config changes to OPNsense.
  def flush
    return unless @pending_config

    client     = api_client
    uuid       = @property_hash[:uuid]
    group_name = resource_group_name
    config     = @pending_config.dup
    config['name'] = group_name

    result = client.post("auth/group/set/#{uuid}", { 'group' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_group: failed to update '#{group_name}' (uuid: #{uuid}): #{result.inspect}"
    end
  end

  private

  # Returns an ApiClient for the current resource's device.
  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  # Extracts the plain group name (before the '@') from the resource title.
  def resource_group_name
    resource[:name].split('@', 2).first
  end
end
