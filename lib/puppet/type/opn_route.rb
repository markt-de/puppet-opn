# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_route) do
  desc <<-DOC
    Manages static routes on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the static route and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Note: The description must be unique per device. Two routes with the same
    description on the same device will cause unpredictable behaviour.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Manage a static route
      opn_route { 'Server network@opnsense.example.com':
        ensure => present,
        config => {
          'network'  => '10.0.0.0/24',
          'gateway'  => 'Wan_DHCP',
          'disabled'  => '0',
        },
      }
  DOC

  # The 'descr' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the static route on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of static route configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        network  - Destination network in CIDR notation (e.g. '10.0.0.0/24')
        gateway  - Gateway key from the OPNsense interface gateways list
        disabled - Whether the route is disabled (0 or 1, default: 0)

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    skip_fields: ['descr'])
end
