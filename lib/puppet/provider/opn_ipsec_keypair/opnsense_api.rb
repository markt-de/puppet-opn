# frozen_string_literal: true

require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_ipsec_keypair).provide(:opnsense_api) do
  desc 'Manages OPNsense IPsec key pairs via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :ipsec

  def self.volatile_fields
    ['keyFingerprint', 'keySize']
  end

  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:ipsec].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('ipsec/keypairs/search', {})
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
      Puppet.warning("opn_ipsec_keypair: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client    = api_client
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    config['name'] = item_name

    result = client.post('ipsec/keypairs/add', { 'keyPair' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_ipsec_keypair: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("ipsec/keypairs/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_ipsec_keypair: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  def flush
    return unless @pending_config

    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    config['name'] = item_name
    self.class.volatile_fields.each { |f| config.delete(f) }

    result = client.post("ipsec/keypairs/set/#{uuid}", { 'keyPair' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_ipsec_keypair: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:ipsec].mark(device, client)
  end
end
