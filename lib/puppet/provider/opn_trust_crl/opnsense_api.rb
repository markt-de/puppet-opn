# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'

Puppet::Type.type(:opn_trust_crl).provide(:opnsense_api) do
  desc 'Manages OPNsense trust CRLs via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client = api_client(device_name)

      # CRL search returns all CAs with optional CRL info.
      # Each row has: descr (CA description), refid (CA ref), crl_descr (CRL description).
      crl_response = client.get('trust/crl/search')
      crl_rows = crl_response['rows'] || []

      crl_rows.each do |crl_entry|
        caref = crl_entry['refid']
        next unless caref

        # Only include CAs that actually have a CRL
        crl_descr = crl_entry['crl_descr'].to_s
        next if crl_descr.empty?

        ca_descr = crl_entry['descr']
        next unless ca_descr

        # Fetch full CRL details
        crl_detail = client.get("trust/crl/get/#{caref}")
        crl_data = crl_detail['crl'] || {}
        config = normalize_config(crl_data)

        instances << new(
          ensure: :present,
          name:   "#{ca_descr}@#{device_name}",
          device: device_name,
          caref:  caref,
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_trust_crl: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client  = api_client
    caref   = resolve_caref(client)
    config  = (resource[:config] || {}).dup

    # CrlController::setAction returns { 'status' => 'saved' } (not 'result')
    result = client.post("trust/crl/set/#{caref}", { 'crl' => config })
    return if result['status'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_trust_crl: failed to create CRL for '#{resource_item_name}': #{result.inspect}"
  end

  def destroy
    client = api_client
    caref  = @property_hash[:caref] || resolve_caref(client)

    # CrlController::delAction returns { 'status' => 'deleted' } (not 'result')
    result = client.post("trust/crl/del/#{caref}", {})
    unless result['status'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_trust_crl: failed to delete CRL for '#{resource_item_name}' " \
            "(caref: #{caref}): #{result.inspect}"
    end

    @property_hash.clear
  end

  def flush
    return unless @pending_config

    client = api_client
    caref  = @property_hash[:caref] || resolve_caref(client)
    config = @pending_config.dup

    result = client.post("trust/crl/set/#{caref}", { 'crl' => config })
    return if result['status'].to_s.strip.downcase == 'saved'
    raise Puppet::Error,
          "opn_trust_crl: failed to update CRL for '#{resource_item_name}' " \
          "(caref: #{caref}): #{result.inspect}"
  end

  private

  # Resolves a CA description to its caref by searching the CA list endpoint.
  def resolve_caref(client)
    ca_descr = resource_item_name
    response = client.get('trust/ca/caList')
    rows     = response['rows'] || []

    ca = rows.find { |r| r['descr'] == ca_descr }
    unless ca
      raise Puppet::Error,
            "opn_trust_crl: CA '#{ca_descr}' not found on device '#{resource[:device]}'"
    end

    ca['caref'] ||
      raise(Puppet::Error, "opn_trust_crl: CA '#{ca_descr}' has no caref")
  end
end
