# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_openvpn_cso) do
  desc <<-DOC
    Manages OpenVPN client-specific overrides (CSO) on an OPNsense device
    via the OPNsense REST API (MVC model).

    The resource title uses the format "common_name@device_name", where
    "common_name" uniquely identifies the override entry and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The servers relation field accepts instance descriptions which are
    automatically resolved to UUIDs via the IdResolver.

    @example Create an OpenVPN client override
      opn_openvpn_cso { 'client1@opnsense.example.com':
        ensure => present,
        config => {
          'servers'          => 'roadwarrior-server',
          'tunnel_network'   => '10.8.1.0/24',
          'local_network'    => '192.168.1.0/24',
          'enabled'          => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "common_name@device_name" format.
      The common_name must uniquely identify the CSO entry on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of OpenVPN CSO configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Relation fields (resolved by name):
        servers - OpenVPN instance descriptions (comma-separated)

      Refer to OPNsense OpenVPN documentation for all valid keys and values.
    DOC
    skip_fields: ['common_name'],
    autorequires: {
      opn_openvpn_instance: { field: 'servers', multiple: true },
    })
end
