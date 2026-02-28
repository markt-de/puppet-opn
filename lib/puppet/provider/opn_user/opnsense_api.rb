# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_user).provide(:opnsense_api) do
  desc 'Manages OPNsense local users via the REST API.'

  # Returns an ApiClient instance for the given device.
  #
  # @param device_name [String]
  # @return [PuppetX::Opn::ApiClient]
  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches all local users from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('auth/user/search', {})
      rows     = response['rows'] || []

      rows.each do |user_data|
        user_name = user_data['name']
        next if user_name.nil? || user_name.empty?

        resource_name = "#{user_name}@#{device_name}"
        config = user_data.reject { |k, _| k == 'uuid' }

        instances << new(
          ensure: :present,
          name:   resource_name,
          device: device_name,
          uuid:   user_data['uuid'],
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_user: failed to fetch users from '#{device_name}': #{e.message}")
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
    client    = api_client
    user_name = resource_user_name
    config    = (resource[:config] || {}).dup
    config['name'] = user_name

    result = client.post('auth/user/add', { 'user' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error, "opn_user: failed to create '#{user_name}': #{result.inspect}"
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    user_name = resource_user_name

    result = client.post("auth/user/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_user: failed to delete '#{user_name}' (uuid: #{uuid}): #{result.inspect}"
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

    client    = api_client
    uuid      = @property_hash[:uuid]
    user_name = resource_user_name
    config    = @pending_config.dup
    config['name'] = user_name

    result = client.post("auth/user/set/#{uuid}", { 'user' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_user: failed to update '#{user_name}' (uuid: #{uuid}): #{result.inspect}"
  end

  private

  # Returns an ApiClient for the current resource's device.
  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  # Extracts the plain user name (before the '@') from the resource title.
  def resource_user_name
    resource[:name].split('@', 2).first
  end
end
