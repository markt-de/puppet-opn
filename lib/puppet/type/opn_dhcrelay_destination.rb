# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_dhcrelay_destination) do
  desc <<-DOC
    Manages DHCP Relay destinations on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name", where
    "name" uniquely identifies the DHCP Relay destination and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Note: The name must be unique per device. Two DHCP Relay destinations
    with the same name on the same device will cause unpredictable
    behaviour.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create a DHCP Relay destination
      opn_dhcrelay_destination { 'DHCP Servers@opnsense.example.com':
        ensure => present,
        config => {
          'server' => '10.0.0.1,10.0.0.2',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "name@device_name" format.
      The name must uniquely identify the DHCP Relay destination on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC

    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, 'Name must be a non-empty string'
      end
    end
  end

  newparam(:device) do
    desc <<-DOC
      The OPNsense device name. If not explicitly set, it is extracted
      from the resource title (the part after the last "@" character).
      Falls back to "default" if no "@" is present in the title.
    DOC

    defaultto do
      title = @resource[:name]
      title.include?('@') ? title.split('@', 2).last : 'default'
    end
  end

  newproperty(:config) do
    desc <<-DOC
      A hash of DHCP Relay destination configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not by
      Puppet.

      Commonly used keys:
        name   - Destination name (set from resource title, not from config)
        server - Comma-separated list of DHCP server IPs

      Refer to OPNsense documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'name' }.all? do |key, value|
        is[key].to_s == value.to_s
      end
    end

    def is_to_s(current_value)
      current_value.inspect
    end

    def should_to_s(new_value)
      new_value.inspect
    end
  end
end
