# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_dhcrelay) do
  desc <<-DOC
    Manages DHCP Relay instances on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "label@device_name", where "label" is a
    freeform identifier chosen by the user (it is NOT sent to the API) and
    "device_name" corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Important: DHCP Relay instances have no name/description field in the
    OPNsense API. The provider matches existing API resources by the
    `interface` value from the config hash. Each interface can only have one
    relay per device.

    The `destination` config key accepts a destination name which is
    automatically resolved to the corresponding UUID by the provider.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create a DHCP Relay on the LAN interface
      opn_dhcrelay { 'LAN IPv4 Relay@opnsense.example.com':
        ensure => present,
        config => {
          'interface'   => 'lan',
          'destination' => 'DHCP Servers',
          'enabled'     => '1',
        },
      }
  DOC

  # Simple comparison with no skipped fields — all should keys are compared.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "label@device_name" format.
      The label is a freeform identifier and is not sent to the OPNsense API.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCP Relay configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        interface      - Network interface for the relay (REQUIRED, selection)
        destination    - Destination name (resolved to UUID by the provider)
        enabled        - Whether the relay is active (1 or 0)
        agent_info     - Agent information option
        carp_depend_on - CARP virtual address dependency

      Refer to OPNsense documentation for all valid keys and values.
    DOC
  )
end
