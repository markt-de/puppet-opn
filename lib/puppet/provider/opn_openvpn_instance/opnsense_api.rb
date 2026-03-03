# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/openvpn_reconfigure'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_openvpn_instance).provide(:opnsense_api) do
  desc 'Manages OPNsense OpenVPN instances via the REST API.'

  def self.volatile_fields
    ['vpnid']
  end

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.relation_fields
    {
      'tls_key' => { endpoint: 'openvpn/instances/search_static_key', multiple: false, name_field: 'description' },
    }.freeze
  end

  def self.post_resource_eval
    PuppetX::Opn::OpenvpnReconfigure.run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('openvpn/instances/search', {})
      rows     = response['rows'] || []

      rows.each do |row|
        item_name = row['description'].to_s
        next if item_name.empty?

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: PuppetX::Opn::IdResolver.translate_to_names(
            client, device_name, relation_fields,
            row.reject { |k, _| k == 'uuid' }
          ),
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_openvpn_instance: failed to fetch from '#{device_name}': #{e.message}")
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
    device    = @property_hash[:device] || resource[:device]
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    config['description'] = item_name
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post('openvpn/instances/add', { 'instance' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_openvpn_instance: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("openvpn/instances/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_openvpn_instance: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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

    client    = api_client
    device    = @property_hash[:device] || resource[:device]
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    config['description'] = item_name
    self.class.volatile_fields.each { |f| config.delete(f) }
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("openvpn/instances/set/#{uuid}", { 'instance' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_openvpn_instance: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
    PuppetX::Opn::OpenvpnReconfigure.mark(device, client)
  end
end
