# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.type(:opn_plugin).provide(:opnsense_api) do
  desc 'Manages OPNsense plugins via the REST API.'

  # Returns an ApiClient instance for the given device.
  #
  # @param device_name [String]
  # @return [PuppetX::Opn::ApiClient]
  def self.api_client(device_name)
    PuppetX::Opn::ApiClient.from_device(device_name)
  end

  # Fetches all installed plugins from all configured OPNsense devices.
  # Uses GET /api/core/firmware/info which returns firmware and package information.
  #
  # The response contains a "package" array where each entry has:
  #   - "name":      the package name
  #   - "installed": "1" when the package is currently installed, "0" otherwise
  #
  # @return [Array<Puppet::Provider>]
  def self.instances
    instances = []

    PuppetX::Opn::ApiClient.device_names.each do |device_name|
      client    = api_client(device_name)
      pkg_names = fetch_installed_plugins(client, device_name)

      pkg_names.each do |pkg_name|
        instances << new(
          ensure: :present,
          name:   "#{pkg_name}@#{device_name}",
          device: device_name,
        )
      end
    rescue Puppet::Error => e
      Puppet.warning("opn_plugin: failed to fetch plugins from '#{device_name}': #{e.message}")
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

  # Fetches the list of installed plugin/package names from a single device.
  # The OPNsense firmware info endpoint returns a "package" array (not "packages").
  #
  # @param client [PuppetX::Opn::ApiClient]
  # @param device_name [String] Used only for warning messages
  # @return [Array<String>] List of installed package names
  def self.fetch_installed_plugins(client, device_name)
    response = client.get('core/firmware/info')
    packages = response['package'] || []

    # The "installed" field is "1" (string) for installed packages.
    installed = packages.select { |pkg| pkg['installed'].to_s == '1' }
    installed.map { |pkg| pkg['name'].to_s }.reject(&:empty?)
  rescue Puppet::Error => e
    Puppet.warning("opn_plugin: could not retrieve package list from '#{device_name}': #{e.message}")
    []
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    client   = api_client
    pkg_name = resource_pkg_name

    client.post("core/firmware/install/#{pkg_name}", {})
  end

  def destroy
    client   = api_client
    pkg_name = resource_pkg_name

    client.post("core/firmware/remove/#{pkg_name}", {})
    @property_hash.clear
  end

  private

  # Returns an ApiClient for the current resource's device.
  def api_client
    device = @property_hash[:device] || resource[:device]
    self.class.api_client(device)
  end

  # Extracts the plain package name (before the '@') from the resource title.
  def resource_pkg_name
    resource[:name].split('@', 2).first
  end
end
