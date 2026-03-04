# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

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

  # The 'name' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The name must uniquely identify the DHCP Relay destination on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCP Relay destination configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not by
      Puppet.

      Commonly used keys:
        name   - Destination name (set from resource title, not from config)
        server - Comma-separated list of DHCP server IPs

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    skip_fields: ['name'])
end
