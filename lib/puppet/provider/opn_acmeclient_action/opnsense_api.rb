# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_acmeclient_action).provide(:opnsense_api) do
  desc 'Manages OPNsense ACME Client automation actions via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('acmeclient/actions/search', {})
      rows     = response['rows'] || []

      rows.each do |row|
        item_name = row['name'].to_s
        next if item_name.empty?

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: row.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_acmeclient_action: failed to fetch from '#{device_name}': #{e.message}")
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
    client    = api_client
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    config['name'] = item_name

    result = client.post('acmeclient/actions/add', { 'action' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error, "opn_acmeclient_action: failed to create '#{item_name}': #{result.inspect}"
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("acmeclient/actions/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_acmeclient_action: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

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

    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    config['name'] = item_name

    result = client.post("acmeclient/actions/update/#{uuid}", { 'action' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_acmeclient_action: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
  end

  private

  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  def resource_item_name
    resource[:name].split('@', 2).first
  end
end
