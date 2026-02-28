# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_snapshot).provide(:opnsense_api) do
  desc 'Manages OPNsense ZFS snapshots via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('core/snapshots/search')
      rows     = response['rows'] || []

      rows.each do |row|
        item_name = row['name'].to_s
        next if item_name.empty?

        active = (row['active'].to_s == '-') ? :false : :true

        # Fetch note via get endpoint (not included in search results)
        detail = client.get("core/snapshots/get/#{row['uuid']}")
        note = detail.is_a?(Hash) ? detail['note'].to_s : ''

        config = row.reject { |k, _| k == 'uuid' }
        config['note'] = note

        instances << new(
          ensure: :present,
          name:   "#{item_name}@#{device_name}",
          device: device_name,
          uuid:   row['uuid'],
          active: active,
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_snapshot: failed to fetch from '#{device_name}': #{e.message}")
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
    item_name = resource_item_name
    config    = (resource[:config] || {}).dup

    # SnapshotsController expects flat POST params (no wrapper key)
    params = { 'name' => item_name }
    params['note'] = config['note'] if config['note']

    result = client.post('core/snapshots/add', params)
    if result.is_a?(Hash) && result['status'].to_s.strip.downcase == 'failed'
      raise Puppet::Error, "opn_snapshot: failed to create '#{item_name}': #{result.inspect}"
    end

    # If active => true requested, find the new snapshot's UUID and activate it
    return unless resource[:active] == :true
    new_uuid = find_uuid_by_name(client, item_name)
    if new_uuid
      client.post("core/snapshots/activate/#{new_uuid}", {})
    else
      Puppet.warning("opn_snapshot: created '#{item_name}' but could not find UUID for activation")
    end
  end

  def destroy
    client    = api_client
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name

    if @property_hash[:active] == :true
      raise Puppet::Error,
            "opn_snapshot: cannot delete active snapshot '#{item_name}' — " \
            'activate a different snapshot first'
    end

    result = client.post("core/snapshots/del/#{uuid}", {})
    if result.is_a?(Hash) && result['status'].to_s.strip.downcase == 'failed'
      raise Puppet::Error,
            "opn_snapshot: failed to delete '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    @property_hash.clear
  end

  def active
    @property_hash[:active]
  end

  def active=(value)
    if value == :true
      client = api_client
      uuid   = @property_hash[:uuid]
      client.post("core/snapshots/activate/#{uuid}", {})
    else
      Puppet.warning(
        "opn_snapshot: cannot deactivate snapshot '#{resource_item_name}' — " \
        'activate a different snapshot instead',
      )
    end
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
    uuid      = @property_hash[:uuid]
    item_name = resource_item_name
    config    = @pending_config.dup

    # SnapshotsController::setAction expects flat POST params
    params = { 'name' => item_name }
    params['note'] = config['note'] if config.key?('note')

    result = client.post("core/snapshots/set/#{uuid}", params)
    return unless result.is_a?(Hash) && result['status'].to_s.strip.downcase == 'failed'
    raise Puppet::Error,
          "opn_snapshot: failed to update '#{item_name}' (uuid: #{uuid}): #{result.inspect}"
  end

  private

  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  def resource_item_name
    resource[:name].split('@', 2).first
  end

  # Searches for a snapshot by name and returns its UUID.
  def find_uuid_by_name(client, snapshot_name)
    response = client.get('core/snapshots/search')
    rows = response['rows'] || []
    row = rows.find { |r| r['name'] == snapshot_name }
    row['uuid'] if row
  end
end
