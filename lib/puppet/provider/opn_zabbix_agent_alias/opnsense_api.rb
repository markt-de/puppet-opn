# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/zabbix_agent_reconfigure'

Puppet::Type.type(:opn_zabbix_agent_alias).provide(:opnsense_api) do
  desc 'Manages OPNsense Zabbix Agent Alias entries via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches all Zabbix Agent aliases from all configured devices.
  # Uses GET /api/zabbixagent/settings/get and navigates to the alias
  # sub-hash (keyed by UUID) to avoid N+1 API calls.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
        client   = api_client(device_name)
        response = client.get('zabbixagent/settings/get')
        items    = response.dig('zabbixagent', 'aliases', 'alias') || {}

        items.each do |uuid, item|
          item_key = item['key'].to_s
          next if item_key.empty?

          instances << new(
            ensure: :present,
            name:   "#{item_key}@#{device_name}",
            device: device_name,
            uuid:   uuid,
            config: item.reject { |k, _| k == 'id' },
          )
        end
      rescue Puppet::Error => e
        Puppet.warning(
          "opn_zabbix_agent_alias: failed to fetch from '#{device_name}': #{e.message}",
        )
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

  # Called once after ALL opn_zabbix_agent* resources are evaluated.
  def self.post_resource_eval
    PuppetX::Opn::ZabbixAgentReconfigure.run
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    client   = api_client
    item_key = resource_item_key
    config   = (resource[:config] || {}).dup
    config['key'] = item_key

    result = client.post('zabbixagent/settings/addAlias', { 'alias' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_zabbix_agent_alias: failed to create '#{item_key}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client   = api_client
    uuid     = @property_hash[:uuid]
    item_key = resource_item_key

    result = client.post("zabbixagent/settings/delAlias/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_zabbix_agent_alias: failed to delete '#{item_key}' " \
            "(uuid: #{uuid}): #{result.inspect}"
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

    client   = api_client
    uuid     = @property_hash[:uuid]
    item_key = resource_item_key
    config   = @pending_config.dup
    config['key'] = item_key

    result = client.post(
      "zabbixagent/settings/setAlias/#{uuid}",
      { 'alias' => config },
    )
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_zabbix_agent_alias: failed to update '#{item_key}' " \
            "(uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  def resource_item_key
    resource[:name].split('@', 2).first
  end

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ZabbixAgentReconfigure.mark(device, client)
  end
end
