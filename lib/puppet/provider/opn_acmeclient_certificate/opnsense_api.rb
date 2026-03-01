# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_uuid_resolver'

Puppet::Type.type(:opn_acmeclient_certificate).provide(:opnsense_api) do
  desc 'Manages OPNsense ACME Client certificates via the REST API.'

  def self.volatile_fields
    ['certRefId', 'lastUpdate', 'statusCode', 'statusLastUpdate']
  end

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.relation_fields
    {
      'account'          => { endpoint: 'acmeclient/accounts/search', multiple: false },
      'validationMethod' => { endpoint: 'acmeclient/validations/search', multiple: false },
      'restartActions'   => { endpoint: 'acmeclient/actions/search', multiple: true },
    }.freeze
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('acmeclient/certificates/search', {})
      rows     = response['rows'] || []

      rows.each do |row|
        item_name = row['name'].to_s
        next if item_name.empty?

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: PuppetX::Opn::HaproxyUuidResolver.translate_to_names(
            client, device_name, relation_fields,
            row.reject { |k, _| k == 'uuid' }
          ),
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_acmeclient_certificate: failed to fetch from '#{device_name}': #{e.message}")
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
    config['name'] = item_name
    config = PuppetX::Opn::HaproxyUuidResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post('acmeclient/certificates/add', { 'certificate' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_acmeclient_certificate: failed to create '#{item_name}': #{result.inspect}"
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("acmeclient/certificates/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_acmeclient_certificate: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
    device    = @property_hash[:device] || resource[:device]
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup
    config['name'] = item_name
    self.class.volatile_fields.each { |f| config.delete(f) }
    config = PuppetX::Opn::HaproxyUuidResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("acmeclient/certificates/update/#{uuid}", { 'certificate' => config })
    return if result['result'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_acmeclient_certificate: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
