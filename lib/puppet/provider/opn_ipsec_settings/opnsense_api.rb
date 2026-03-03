# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/ipsec_reconfigure'

Puppet::Type.type(:opn_ipsec_settings).provide(:opnsense_api) do
  desc 'Manages OPNsense IPsec global settings via the REST API.'

  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  def self.settings_sections
    ['general', 'charon'].freeze
  end

  def self.post_resource_eval
    PuppetX::Opn::IpsecReconfigure.run
  end

  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client   = api_client(device_name)
      response = client.get('ipsec/settings/get')
      data     = response['ipsec'] || {}

      config = data.slice(*settings_sections)
      config = normalize_config(config)
      normalize_enabled(config)

      instances << new(
        ensure: :present,
        name:   device_name,
        config: config,
      )
    rescue Puppet::Error => e
      Puppet.warning("opn_ipsec_settings: failed to fetch from '#{device_name}': #{e.message}")
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

  # Normalize OPNsense selection hashes to simple comma-separated strings.
  def self.normalize_config(obj)
    return obj unless obj.is_a?(Hash)
    return normalize_selection(obj) if selection_hash?(obj)

    obj.transform_values { |v| normalize_config(v) }
  end

  def self.selection_hash?(hash)
    hash.is_a?(Hash) &&
      !hash.empty? &&
      hash.values.all? { |v| v.is_a?(Hash) && v.key?('value') && v.key?('selected') }
  end

  def self.normalize_selection(hash)
    hash.select { |_k, v| v['selected'].to_i == 1 }.keys.join(',')
  end

  # Normalize the general.enabled field from API response.
  #
  # In the OPNsense IPsec model, general.enabled is a LegacyLinkField that
  # reads from the legacy config path 'ipsec.enable'. When IPsec is disabled,
  # the legacy config element is absent and the field returns "" (empty string).
  # We normalize this to "0" so that insync? comparisons work correctly when
  # the user specifies enabled => "0" in their Puppet config.
  def self.normalize_enabled(config)
    general = config['general']
    return unless general.is_a?(Hash) && general.key?('enabled')

    general['enabled'] = '0' if general['enabled'].to_s.empty?
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    apply_config(resource[:config] || {})
  end

  def destroy
    client = api_client
    save_settings(client, {})
    mark_reconfigure(client)
    @property_hash.clear
  end

  def config
    @property_hash[:config]
  end

  def config=(value)
    @pending_config = value
  end

  def flush
    return unless @pending_config

    apply_config(@pending_config)
  end

  private

  def api_client
    self.class.api_client(resource[:name])
  end

  # Save IPsec settings, handling the general.enabled field separately.
  #
  # The general.enabled field in the OPNsense IPsec model is a LegacyLinkField
  # backed by the legacy config path 'ipsec.enable'. LegacyLinkField.setValue()
  # is a no-op — writes via ipsec/settings/set are silently ignored. Instead,
  # we use the ipsec/connections/toggle endpoint which directly modifies the
  # legacy config.xml value.
  def save_settings(client, config)
    enabled_value = extract_enabled(config)
    result = client.post('ipsec/settings/set', { 'ipsec' => config })
    unless result['result'].to_s.strip.downcase == 'saved'
      raise Puppet::Error,
            "opn_ipsec_settings: failed to save settings for '#{resource[:name]}': #{result.inspect}"
    end
    toggle_enabled(client, enabled_value) unless enabled_value.nil?
  end

  # Extract and remove the 'enabled' key from the general section.
  # Returns the enabled value if present, nil otherwise.
  def extract_enabled(config)
    general = config['general']
    return nil unless general.is_a?(Hash) && general.key?('enabled')

    general.delete('enabled')
  end

  # Toggle IPsec enabled state via ipsec/connections/toggle endpoint.
  # This endpoint directly writes to config.xml -> ipsec.enable, bypassing
  # the MVC model's read-only LegacyLinkField.
  def toggle_enabled(client, value)
    result = client.post("ipsec/connections/toggle/#{value}")
    return if result['status'].to_s.strip.downcase == 'ok'

    raise Puppet::Error,
          "opn_ipsec_settings: failed to toggle IPsec enabled for '#{resource[:name]}': #{result.inspect}"
  end

  def apply_config(config)
    client = api_client
    save_settings(client, config)
    mark_reconfigure(client)
  end

  def mark_reconfigure(client)
    PuppetX::Opn::IpsecReconfigure.mark(resource[:name], client)
  end
end
