# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_trust_cert).provide(:opnsense_api) do
  desc 'Manages OPNsense trust certificates via the REST API.'

  VOLATILE_FIELDS = %w[
    action key_type digest cert_type lifetime private_key_location
    city state organization organizationalunit country email commonname
    ocsp_uri altnames_dns altnames_ip altnames_uri altnames_email
    crt_payload csr_payload prv_payload rfc3280_purpose in_use is_user
    name valid_from valid_to
  ].freeze

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
        client   = api_client(device_name)
        response = client.post('trust/cert/search', {})
        rows     = response['rows'] || []

        rows.each do |row|
          descr = row['descr'].to_s
          next if descr.empty?

          instances << new(
            ensure: :present,
            name:   "#{descr}@#{device_name}",
            device: device_name,
            uuid:   row['uuid'],
            config: row.reject { |k, _| k == 'uuid' },
          )
        end
      rescue Puppet::Error => e
        Puppet.warning("opn_trust_cert: failed to fetch from '#{device_name}': #{e.message}")
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

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    client = api_client
    descr  = resource_item_name
    config = (resource[:config] || {}).dup
    config['descr'] = descr

    result = client.post('trust/cert/add', { 'cert' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_trust_cert: failed to create '#{descr}': #{result.inspect}"
    end
  end

  def destroy
    client = api_client
    uuid   = @property_hash[:uuid]
    descr  = resource_item_name

    result = client.post("trust/cert/del/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_trust_cert: failed to delete '#{descr}' (uuid: #{uuid}): #{result.inspect}"
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

    client = api_client
    uuid   = @property_hash[:uuid]
    descr  = resource_item_name
    config = @pending_config.dup
    config['descr'] = descr
    VOLATILE_FIELDS.each { |f| config.delete(f) }

    result = client.post("trust/cert/set/#{uuid}", { 'cert' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_trust_cert: failed to update '#{descr}' (uuid: #{uuid}): #{result.inspect}"
    end
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
