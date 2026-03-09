# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_route).provide(:opnsense_api) do
  desc 'Manages OPNsense static routes via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :route

  # Delegates reconfigure to ServiceReconfigure after all opn_route
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:route].run
  end

  # Fetches all static routes from every configured OPNsense device.
  # The API field 'descr' is used as the human-readable identifier.
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('routes/routes/searchroute', {})
      rows     = response['rows'] || []

      rows.each do |row|
        description = row['descr'].to_s
        next if description.empty?

        instances << new(
          ensure: :present,
          name:   "#{description}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          config: row.reject { |k, _| k == 'uuid' },
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_route: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  # Creates a new static route via the API.
  # Injects the description from the resource title as 'descr' (OPNsense model field name).
  def create
    client      = api_client
    description = resource_item_name
    config      = (resource[:config] || {}).dup
    config['descr'] = description

    result = client.post('routes/routes/addroute', { 'route' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_route: failed to create '#{description}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_item_name

    result = client.post("routes/routes/delroute/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_route: failed to delete '#{description}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  # Updates an existing static route via the API.
  # Uses 'setroute' (not 'update') — OPNsense core routes follow the standard set pattern.
  def flush
    return unless @pending_config

    client      = api_client
    uuid        = @property_hash[:uuid]
    description = resource_item_name
    config      = @pending_config.dup
    config['descr'] = description

    result = client.post("routes/routes/setroute/#{uuid}", { 'route' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_route: failed to update '#{description}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:route].mark(device, client)
  end
end
