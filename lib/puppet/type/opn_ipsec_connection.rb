# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_connection) do
  desc <<-DOC
    Manages IPsec connections on an OPNsense device via the OPNsense REST API
    (Swanctl/MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the connection and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Volatile fields (local_ts, remote_ts) are computed from children and
    excluded from idempotency checks.

    @example Create an IPsec connection
      opn_ipsec_connection { 'site-to-site@opnsense.example.com':
        ensure => present,
        config => {
          'version'    => '2',
          'proposals'  => 'aes256-sha256-modp2048',
          'local_addrs' => '0.0.0.0/0',
          'remote_addrs' => '198.51.100.1',
          'enabled'    => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the connection on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec connection configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Volatile fields (excluded from idempotency checks):
        local_ts, remote_ts (computed from children)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['description'],
    volatile_fields: ['local_ts', 'remote_ts'])
end
