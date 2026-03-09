# frozen_string_literal: true

require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_ipsec_child).provide(:opnsense_api) do
  desc 'Manages OPNsense IPsec child SAs via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :ipsec

  def self.relation_fields
    {
      'connection' => { endpoint: 'ipsec/connections/searchConnection', multiple: false, name_field: 'description' },
    }.freeze
  end

  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:ipsec].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('ipsec/connections/searchChild', {})
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
      Puppet.warning("opn_ipsec_child: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
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

    result = client.post('ipsec/connections/addChild', { 'child' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_ipsec_child: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("ipsec/connections/delChild/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_ipsec_child: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
    config['description'] = item_name
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("ipsec/connections/setChild/#{uuid}", { 'child' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_ipsec_child: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:ipsec].mark(device, client)
  end
end
