# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_dhcpv6_subnet) do
  desc <<-DOC
    Manages KEA DHCPv6 subnets on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "subnet_cidr@device_name", where
    "subnet_cidr" is the CIDR notation (e.g. 'fd00::/64') that uniquely
    identifies the subnet and "device_name" corresponds to a YAML config file
    managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    The subnet CIDR has a UniqueConstraint in the OPNsense model, so it serves
    as the natural identifier. Reservations and PD pools autorequire their
    parent subnet.

    @example Create a DHCPv6 subnet
      opn_kea_dhcpv6_subnet { 'fd00::/64@opnsense.example.com':
        ensure => present,
        config => {
          'description' => 'LAN DHCPv6',
          'interface'   => 'lan',
          'option_data' => {
            'dns_servers' => 'fd00::1',
          },
          'pools' => 'fd00::100 - fd00::200',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "subnet_cidr@device_name" format.
      The subnet_cidr must be a valid IPv6 CIDR notation (e.g. 'fd00::/64')
      that uniquely identifies the subnet on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCPv6 subnet configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        description   - Human-readable description
        allocator     - Address allocation strategy
        pd-allocator  - Prefix delegation allocator
        interface     - Network interface
        option_data   - Hash of DHCPv6 options (dns_servers, domain_search, ...)
        pools         - Pool range (e.g. 'fd00::100 - fd00::200')

      Fields with selection hashes (normalized automatically):
        allocator    - OptionField
        pd-allocator - OptionField
        interface    - InterfaceField

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    insync_mode: :deep_match)
end
