# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_openvpn_instance) do
  desc <<-DOC
    Manages OpenVPN instances on an OPNsense device via the OPNsense REST API
    (MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the instance and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The 'password' field is intentionally excluded from idempotency
    comparison because it contains secret material.

    Volatile fields (vpnid) are auto-assigned by OPNsense and excluded from
    idempotency checks.

    The tls_key relation field accepts a static key description which is
    automatically resolved to a UUID via the IdResolver.

    @example Create an OpenVPN server instance
      opn_openvpn_instance { 'roadwarrior-server@opnsense.example.com':
        ensure => present,
        config => {
          'role'           => 'server',
          'proto'          => 'udp',
          'port'           => '1194',
          'server'         => '10.8.0.0/24',
          'tls_key'        => 'my-tls-auth-key',
          'enabled'        => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the instance on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of OpenVPN instance configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      The 'password' field is excluded from idempotency comparison because
      it contains secret material.

      Volatile fields (excluded from idempotency checks):
        vpnid (auto-assigned numeric ID)

      Relation fields (resolved by name):
        tls_key - OpenVPN static key description (single)

      Refer to OPNsense OpenVPN documentation for all valid keys and values.
    DOC
    skip_fields: ['description'],
    volatile_fields: ['vpnid'],
    password_fields: ['password'],
    autorequires: {
      opn_openvpn_statickey: { field: 'tls_key' },
    })
end
