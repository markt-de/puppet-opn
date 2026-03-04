# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_tunable).provide(:opnsense_api) do
  desc 'Manages OPNsense system tunables via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods

  # Delegates reconfigure to ServiceReconfigure after all opn_tunable
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:tunable].run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('core/tunables/search_item', {})
      rows     = response['rows'] || []

      rows.each do |row|
        tunable = row['tunable'].to_s
        next if tunable.empty?

        instances << new(
          ensure: :present,
          name:   "#{tunable}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: row.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_tunable: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  def create
    client  = api_client
    tunable = resource_item_name
    config  = (resource[:config] || {}).dup
    config['tunable'] = tunable

    result = client.post('core/tunables/add_item', { 'sysctl' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_tunable: failed to create '#{tunable}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client  = api_client
    uuid    = @property_hash[:uuid]
    tunable = resource_item_name

    result = client.post("core/tunables/del_item/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_tunable: failed to delete '#{tunable}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  def flush
    return unless @pending_config

    client  = api_client
    uuid    = @property_hash[:uuid]
    tunable = resource_item_name
    config  = @pending_config.dup
    config['tunable'] = tunable

    result = client.post("core/tunables/set_item/#{uuid}", { 'sysctl' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_tunable: failed to update '#{tunable}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:tunable].mark(device, client)
  end
end
