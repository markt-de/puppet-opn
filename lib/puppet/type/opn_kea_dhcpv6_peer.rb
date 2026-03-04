# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_dhcpv6_peer) do
  desc <<-DOC
    Manages KEA DHCPv6 HA peers on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the HA peer and "device_name" corresponds to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    @example Create a DHCPv6 HA peer
      opn_kea_dhcpv6_peer { 'primary-node@opnsense.example.com':
        ensure => present,
        config => {
          'role' => 'primary',
          'url'  => 'http://[fd00::1]:8000',
        },
      }
  DOC

  # The 'name' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "peer_name@device_name" format.
      The peer_name must uniquely identify the HA peer on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCPv6 HA peer configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        role - Peer role (primary, standby, etc.)
        url  - Peer URL for HA communication

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    skip_fields: ['name'])
end
