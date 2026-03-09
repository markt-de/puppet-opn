# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/provider_base'
require 'puppet_x/opn/service_reconfigure_registry'

Puppet::Type.type(:opn_firewall_group).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall interface groups via the REST API.'

  extend  PuppetX::Opn::ProviderBase::ClassMethods
  include PuppetX::Opn::ProviderBase::InstanceMethods
  reconfigure_group :firewall_group

  # Delegates reconfigure to ServiceReconfigure after all opn_firewall_group
  # resources have been evaluated in this catalog run.
  def self.post_resource_eval
    PuppetX::Opn::ServiceReconfigure[:firewall_group].run
  end

  # Fetches all user-managed firewall interface groups from all configured devices.
  # System-provided groups (enc0/IPsec, openvpn, wireguard) are identified by
  # having a non-UUID value in the uuid field and are excluded.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.post('firewall/group/search_item', {})
      rows     = response['rows'] || []

      rows.each do |group_data|
        uuid = group_data['uuid'].to_s
        # Skip system-managed groups: they have non-UUID values (e.g. "enc0", "openvpn")
        next unless uuid.match?(%r{\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z}i)

        ifname = group_data['ifname']
        next if ifname.nil? || ifname.empty?

        resource_name = "#{ifname}@#{device_name}"
        config = group_data.reject { |k, _| k == 'uuid' }

        instances << new(
          ensure: :present,
          name:   resource_name,
          device: device_name,
          uuid:   uuid,
          config: config,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning(
        "opn_firewall_group: failed to fetch groups from '#{device_name}': #{e.message}",
      )
    end

    instances
  end

  def create
    client  = api_client
    ifname  = resource_ifname
    config  = (resource[:config] || {}).dup
    config['ifname'] = ifname

    result = client.post('firewall/group/add_item', { 'group' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_group: failed to create '#{ifname}': #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  def destroy
    client = api_client
    uuid   = @property_hash[:uuid]
    ifname = resource_ifname

    result = client.post("firewall/group/del_item/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_firewall_group: failed to delete '#{ifname}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
    @property_hash.clear
  end

  # Applies pending config changes to OPNsense.
  # reconfigure is NOT called here – it is deferred to post_resource_eval.
  def flush
    return unless @pending_config

    client = api_client
    uuid   = @property_hash[:uuid]
    ifname = resource_ifname
    config = @pending_config.dup
    config['ifname'] = ifname

    result = client.post("firewall/group/set_item/#{uuid}", { 'group' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_group: failed to update '#{ifname}' (uuid: #{uuid}): #{result.inspect}"
    end

    mark_reconfigure(client)
  end

  private

  # Extracts the plain interface group name (before the '@') from the resource title.
  def resource_ifname
    resource[:name].split('@', 2).first
  end

  # Registers the device as needing a reconfigure at the end of the Puppet run.
  # The actual API call is made once in post_resource_eval via ServiceReconfigure.
  def mark_reconfigure(client)
    device = @property_hash[:device] || resource[:device]
    PuppetX::Opn::ServiceReconfigure[:firewall_group].mark(device, client)
  end
end
