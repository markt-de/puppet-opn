# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_firewall_rule).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall filter rules via the REST API.'

  # Tracks devices that have pending rule changes during this Puppet run.
  # Maps device_name => ApiClient instance.
  # Populated by create/destroy/flush; consumed by post_resource_eval.
  @devices_to_reconfigure = {}

  def self.devices_to_reconfigure
    @devices_to_reconfigure
  end

  # Called by Puppet once after ALL opn_firewall_rule resources have been
  # evaluated in this catalog run. Triggers exactly one apply API call per
  # device that had at least one rule change, then clears the tracking hash.
  def self.post_resource_eval
    @devices_to_reconfigure.each do |device_name, client|
      begin
        result = client.post('firewall/filter/apply', {})
        # Guard against non-Hash responses (e.g. JSON null → nil).
        # Strip whitespace and downcase because OPNsense returns "OK\n\n".
        status = result.is_a?(Hash) ? result['status'].to_s.strip.downcase : nil
        if status == 'ok'
          Puppet.notice("opn_firewall_rule: apply on '#{device_name}' completed")
        else
          Puppet.warning(
            "opn_firewall_rule: apply on '#{device_name}' returned unexpected status: #{result.inspect}",
          )
        end
      rescue Puppet::Error => e
        Puppet.err("opn_firewall_rule: apply on '#{device_name}' failed: #{e.message}")
      end
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

  # Fetches all firewall rules from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
        client   = api_client(device_name)
        response = client.post('firewall/filter/search_rule', {})
        rows     = response['rows'] || []

        rows.each do |rule_data|
          description = rule_data['description']
          next if description.nil? || description.empty?

          resource_name = "#{description}@#{device_name}"
          config = rule_data.reject { |k, _| k == 'uuid' }

          instances << new(
            ensure: :present,
            name:   resource_name,
            device: device_name,
            uuid:   rule_data['uuid'],
            config: config,
          )
        end
      rescue Puppet::Error => e
        Puppet.warning(
          "opn_firewall_rule: failed to fetch rules from '#{device_name}': #{e.message}",
        )
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
    client      = api_client
    description = resource_description
    config      = (resource[:config] || {}).dup
    config['description'] = description

    result = client.post('firewall/filter/add_rule', { 'rule' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_rule: failed to create '#{description}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_description

    result = client.post("firewall/filter/del_rule/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_firewall_rule: failed to delete '#{description}' (uuid: #{uuid}): #{result.inspect}"
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
  # apply is NOT called here – it is deferred to post_resource_eval.
  def flush
    return unless @pending_config

    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_description
    config      = @pending_config.dup
    config['description'] = description

    result = client.post("firewall/filter/set_rule/#{uuid}", { 'rule' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_rule: failed to update '#{description}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  # Returns an ApiClient for the current resource's device.
  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  # Extracts the plain description (before the '@') from the resource title.
  def resource_description
    resource[:name].split('@', 2).first
  end

  # Registers the device as needing an apply at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    self.class.devices_to_reconfigure[device] ||= client
  end
end
