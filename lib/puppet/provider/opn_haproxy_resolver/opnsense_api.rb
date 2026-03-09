# frozen_string_literal: true

require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_haproxy_resolver).provide(:opnsense_api) do
  desc 'Manages OPNsense HAProxy DNS resolvers via the REST API.'

  # NOTE: resolver endpoints use no underscore separator (HAProxy plugin peculiarity):
  #   searchresolvers / addresolver / setresolver / delresolver

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :haproxy

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('haproxy/settings/searchresolvers', {})
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
      Puppet.warning("opn_haproxy_resolver: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  # Called once after ALL opn_haproxy_resolver resources are evaluated.
  # Delegates to shared module — first call does the work, rest are no-ops.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:haproxy].run
  end

  def create
    client    = api_client
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    config['name'] = item_name

    result = client.post('haproxy/settings/addresolver', { 'resolver' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_haproxy_resolver: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("haproxy/settings/delresolver/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_haproxy_resolver: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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

    result = client.post("haproxy/settings/setresolver/#{uuid}", { 'resolver' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_haproxy_resolver: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:haproxy].mark(device, client)
  end
end
