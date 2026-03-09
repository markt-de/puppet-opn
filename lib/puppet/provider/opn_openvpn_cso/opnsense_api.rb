# frozen_string_literal: true

require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_openvpn_cso).provide(:opnsense_api) do
  desc 'Manages OPNsense OpenVPN client-specific overrides via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :openvpn

  def self.relation_fields
    {
      'servers' => { endpoint: 'openvpn/instances/search', multiple: true, name_field: 'description' },
    }.freeze
  end

  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:openvpn].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('openvpn/client_overwrites/search', {})
      rows     = response['rows'] || []

      rows.each do |row|
        item_name = row['common_name'].to_s
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
      Puppet.warning("opn_openvpn_cso: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client    = api_client
    device    = @property_hash[:device] || resource[:device]
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    config['common_name'] = item_name
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post('openvpn/client_overwrites/add', { 'cso' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_openvpn_cso: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("openvpn/client_overwrites/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_openvpn_cso: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  def flush
    return unless @pending_config

    client    = api_client
    device    = @property_hash[:device] || resource[:device]
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    config['common_name'] = item_name
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("openvpn/client_overwrites/set/#{uuid}", { 'cso' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_openvpn_cso: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:openvpn].mark(device, client)
  end
end
