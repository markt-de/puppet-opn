# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_dhcpv4_reservation) do
  desc <<-DOC
    Manages KEA DHCPv4 reservations on an OPNsense device via the OPNsense
    REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the reservation and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The subnet relation field accepts a subnet CIDR which is automatically
    resolved to a UUID via the IdResolver.

    @example Create a DHCPv4 reservation
      opn_kea_dhcpv4_reservation { 'Web Server@opnsense.example.com':
        ensure => present,
        config => {
          'subnet'     => '192.168.1.0/24',
          'hw_address' => 'AA:BB:CC:DD:EE:FF',
          'ip_address' => '192.168.1.10',
          'hostname'   => 'webserver',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the reservation on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCPv4 reservation configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Relation fields (resolved by name):
        subnet - DHCPv4 subnet CIDR (single)

      Commonly used keys:
        subnet      - Parent subnet CIDR (e.g. '192.168.1.0/24')
        hw_address  - MAC address of the client
        ip_address  - Reserved IP address
        hostname    - Client hostname
        option_data - Hash of DHCP options

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    insync_mode: :deep_match,
    autorequires: {
      opn_kea_dhcpv4_subnet: { field: 'subnet' },
    })
end
