# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_firewall_rule).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall filter rules via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Delegates apply to ServiceReconfigure after all opn_firewall_rule
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:firewall_rule].run
  end

  # Fetches all firewall rules from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
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

    instances
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

  # Extracts the plain description (before the '@') from the resource title.
  def resource_description
    resource[:name].split('@', 2).first
  end

  # Registers the device as needing an apply at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:firewall_rule].mark(device, client)
  end
end
