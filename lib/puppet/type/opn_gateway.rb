# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_gateway) do
  desc <<-DOC
    Manages gateways on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the gateway (e.g. "WAN_GW") and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Note: The gateway name must be unique per device and cannot be changed
    after creation (OPNsense restriction). The name may only consist of the
    characters "a-zA-Z0-9_-" and must be less than 32 characters long.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Manage a gateway
      opn_gateway { 'WAN_GW@opnsense.example.com':
        ensure => present,
        config => {
          'interface'       => 'wan',
          'ipprotocol'      => 'inet',
          'gateway'         => '192.168.1.1',
          'descr'           => 'WAN Gateway',
          'monitor_disable' => '1',
          'priority'        => '255',
          'weight'          => '1',
        },
      }
  DOC

  # The 'name' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The name must uniquely identify the gateway on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of gateway configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        interface       - Network interface (e.g. 'wan')
        ipprotocol      - Address family: 'inet' (IPv4) or 'inet6' (IPv6)
        gateway         - Gateway IP address
        descr           - Human-readable description
        disabled        - Whether the gateway is disabled (0 or 1, default: 0)
        defaultgw       - Whether this is the default gateway (0 or 1)
        fargw           - Far gateway / not on same subnet (0 or 1)
        monitor_disable - Disable gateway monitoring (0 or 1, default: 1)
        monitor         - Alternative monitor IP address
        priority        - Gateway priority (0-255, default: 255)
        weight          - Gateway weight (1-5, default: 1)

      The 'name' field is injected from the resource title and excluded
      from idempotency checks.

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    skip_fields: ['name'])
end
