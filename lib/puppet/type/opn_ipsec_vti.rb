# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_vti) do
  desc <<-DOC
    Manages IPsec VTI (Virtual Tunnel Interface) entries on an OPNsense
    device via the OPNsense REST API (Swanctl/MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the VTI and "device_name" corresponds
    to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Volatile fields (origin) are computed by OPNsense and excluded from
    idempotency checks.

    @example Create an IPsec VTI
      opn_ipsec_vti { 'tunnel-to-remote@opnsense.example.com':
        ensure => present,
        config => {
          'reqid'       => '100',
          'local'       => '10.0.0.1',
          'remote'      => '10.0.0.2',
          'tunnel_local'  => '10.10.0.1/30',
          'tunnel_remote' => '10.10.0.2/30',
          'enabled'     => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the VTI on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec VTI configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Volatile fields (excluded from idempotency checks):
        origin (computed, indicates legacy vs new)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['description'],
    volatile_fields: ['origin'])
end
