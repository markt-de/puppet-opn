# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_firewall_category).provide(:opnsense_api) do
  desc 'Manages OPNsense firewall categories via the REST API.'

  # Returns an ApiClient instance for the given device.
  #
  # @param device_name [String]
  # @return [PuppetX::Opn::ApiClient]
  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches all firewall categories from all configured OPNsense devices.
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      begin
        client   = api_client(device_name)
        response = client.post('firewall/category/search_item', {})
        rows     = response['rows'] || []

        rows.each do |cat_data|
          cat_name = cat_data['name']
          next if cat_name.nil? || cat_name.empty?

          resource_name = "#{cat_name}@#{device_name}"
          config = cat_data.reject { |k, _| k == 'uuid' }

          instances << new(
            ensure: :present,
            name:   resource_name,
            device: device_name,
            uuid:   cat_data['uuid'],
            config: config,
          )
        end
      rescue Puppet::Error => e
        Puppet.warning(
          "opn_firewall_category: failed to fetch categories from '#{device_name}': #{e.message}",
        )
      end
    end

    instances
  end

  # Matches provider instances to Puppet resources.
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
    client   = api_client
    cat_name = resource_cat_name
    config   = (resource[:config] || {}).dup
    config['name'] = cat_name

    result = client.post('firewall/category/add_item', { 'category' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_category: failed to create '#{cat_name}': #{result.inspect}"
    end
  end

  def destroy
    client   = api_client
    uuid     = @property_hash[:uuid]
    cat_name = resource_cat_name

    result = client.post("firewall/category/del_item/#{uuid}", {})
    unless result['result'].to_s.strip.downcase == 'deleted'
      raise Puppet::Error,
            "opn_firewall_category: failed to delete '#{cat_name}' (uuid: #{uuid}): #{result.inspect}"
    end

    @property_hash.clear
  end

  def config
    @property_hash[:config]
  end

  def config=(value)
    @pending_config = value
  end

  # Applies pending config changes to OPNsense.
  def flush
    return unless @pending_config

    client   = api_client
    uuid     = @property_hash[:uuid]
    cat_name = resource_cat_name
    config   = @pending_config.dup
    config['name'] = cat_name

    result = client.post("firewall/category/set_item/#{uuid}", { 'category' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_firewall_category: failed to update '#{cat_name}' (uuid: #{uuid}): #{result.inspect}"
    end
  end

  private

  # Returns an ApiClient for the current resource's device.
  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  # Extracts the plain category name (before the '@') from the resource title.
  def resource_cat_name
    resource[:name].split('@', 2).first
  end
end
