# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/haproxy_reconfigure'
require 'puppet_x/opn/haproxy_uuid_resolver'

Puppet::Type.type(:opn_haproxy_backend).provide(:opnsense_api) do
  desc 'Manages OPNsense HAProxy backend pools via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.relation_fields
    {
      'linkedServers'        => { endpoint: 'haproxy/settings/search_servers',      multiple: true  },
      'linkedFcgi'           => { endpoint: 'haproxy/settings/search_fcgis',        multiple: false },
      'linkedResolver'       => { endpoint: 'haproxy/settings/searchresolvers',     multiple: false },
      'healthCheck'          => { endpoint: 'haproxy/settings/search_healthchecks', multiple: false },
      'linkedMailer'         => { endpoint: 'haproxy/settings/searchmailers',       multiple: false },
      'linkedActions'        => { endpoint: 'haproxy/settings/search_actions',      multiple: true  },
      'linkedErrorfiles'     => { endpoint: 'haproxy/settings/search_errorfiles',   multiple: true  },
      'basicAuthUsers'       => { endpoint: 'haproxy/settings/search_users',        multiple: true  },
      'basicAuthGroups'      => { endpoint: 'haproxy/settings/search_groups',       multiple: true  },
      'sslCA'                => { endpoint: 'trust/ca/search',   multiple: true,  id_field: 'refid', name_field: 'descr' },
      'sslCRL'               => { endpoint: 'trust/crl/search',  multiple: false, id_field: 'refid', name_field: 'crl_descr', method: :get },
      'sslClientCertificate' => { endpoint: 'trust/cert/search', multiple: false, id_field: 'refid', name_field: 'descr' },
    }.freeze
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('haproxy/settings/search_backends', {})
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
      Puppet.warning("opn_haproxy_backend: failed to fetch from '#{device_name}': #{e.message}")
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

  # Called once after ALL opn_haproxy_backend resources are evaluated.
  # Delegates to shared module — first call does the work, rest are no-ops.
  def self.post_resource_eval
    PuppetX::Opn::HaproxyReconfigure.run
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

    result = client.post('haproxy/settings/add_backend', { 'backend' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error, "opn_haproxy_backend: failed to create '#{item_name}': #{result.inspect}"
    end

    mark_reconfigure(client)
  rescue
    PuppetX::Opn::HaproxyReconfigure.mark_error(@property_hash[:device] || resource[:device])
    raise
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    result = client.post("haproxy/settings/del_backend/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_haproxy_backend: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  rescue
    PuppetX::Opn::HaproxyReconfigure.mark_error(@property_hash[:device] || resource[:device])
    raise
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
    config = PuppetX::Opn::HaproxyUuidResolver.translate_to_uuids(
      client, device, self.class.relation_fields, config
    )

    result = client.post("haproxy/settings/set_backend/#{uuid}", { 'backend' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_haproxy_backend: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  rescue
    PuppetX::Opn::HaproxyReconfigure.mark_error(@property_hash[:device] || resource[:device])
    raise
  end

  private

  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  def resource_item_name
    resource[:name].split('@', 2).first
  end

  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::HaproxyReconfigure.mark(device, client)
  end
end
