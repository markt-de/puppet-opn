# frozen_string_literal: true

require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'
require 'puppet_x/opn/id_resolver'

Puppet::Type.type(:opn_haproxy_acl).provide(:opnsense_api) do
  desc 'Manages OPNsense HAProxy ACL rules via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :haproxy

  def self.relation_fields
    {
      'linkedResolver'               => { endpoint: 'haproxy/settings/searchresolvers',    multiple: false },
      'unix_socket'                  => { endpoint: 'haproxy/settings/search_luas',        multiple: false },
      'linkedAcls'                   => { endpoint: 'haproxy/settings/search_acls',        multiple: true  },
      'use_backend'                  => { endpoint: 'haproxy/settings/search_backends',    multiple: false },
      'use_server'                   => { endpoint: 'haproxy/settings/search_servers',     multiple: false },
      'nbsrv_backend'                => { endpoint: 'haproxy/settings/search_backends',    multiple: false },
      'queryBackend'                 => { endpoint: 'haproxy/settings/search_backends',    multiple: false },
      'allowedUsers'                 => { endpoint: 'haproxy/settings/search_users',       multiple: true  },
      'allowedGroups'                => { endpoint: 'haproxy/settings/search_groups',      multiple: true  },
      'mapfile'                      => { endpoint: 'haproxy/settings/search_mapfiles',    multiple: false },
      'map_data_use_backend_file'    => { endpoint: 'haproxy/settings/search_mapfiles',    multiple: false },
      'map_data_use_backend_default' => { endpoint: 'haproxy/settings/search_backends', multiple: false },
      'map_use_backend_file'         => { endpoint: 'haproxy/settings/search_mapfiles', multiple: false },
      'map_use_backend_default'      => { endpoint: 'haproxy/settings/search_backends', multiple: false },
      'linkedActions'                => { endpoint: 'haproxy/settings/search_actions', multiple: true },
    }.freeze
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('haproxy/settings/search_acls', {})
      rows     = response['rows'] || []

      rows.each do |row|
        item_name = row['name'].to_s
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
      Puppet.warning("opn_haproxy_acl: failed to fetch from '#{device_name}': #{e.message}")
    end

    instances
  end

  # Called once after ALL opn_haproxy_acl resources are evaluated.
  # Delegates to shared module — first call does the work, rest are no-ops.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:haproxy].run
  end

  def create
    client    = api_client
    device    = @property_hash[:device] || resource[:device]
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup
    config['name'] = item_name
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post('haproxy/settings/add_acl', { 'acl' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_haproxy_acl: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("haproxy/settings/del_acl/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_haproxy_acl: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
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
    config['name'] = item_name
    config = PuppetX::Opn::IdResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("haproxy/settings/set_acl/#{uuid}", { 'acl' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_haproxy_acl: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:haproxy].mark(device, client)
  end
end
