# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_dhcpv6_pd_pool) do
  desc <<-DOC
    Manages KEA DHCPv6 prefix delegation pools on an OPNsense device via the
    OPNsense REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the PD pool and "device_name" corresponds
    to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The subnet relation field accepts a subnet CIDR which is automatically
    resolved to a UUID via the IdResolver.

    @example Create a DHCPv6 prefix delegation pool
      opn_kea_dhcpv6_pd_pool { 'Customer PD Pool@opnsense.example.com':
        ensure => present,
        config => {
          'subnet'        => 'fd00::/64',
          'prefix'        => 'fd00:1::/48',
          'prefix_len'    => '48',
          'delegated_len' => '64',
        },
      }
  DOC

  # The 'description' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the PD pool on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCPv6 PD pool configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Relation fields (resolved by name):
        subnet - DHCPv6 subnet CIDR (single)

      Commonly used keys:
        subnet        - Parent subnet CIDR (e.g. 'fd00::/64')
        prefix        - Delegated prefix
        prefix_len    - Prefix length
        delegated_len - Delegated prefix length

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    skip_fields: ['description'],
    autorequires: {
      opn_kea_dhcpv6_subnet: { field: 'subnet' },
    })
end
