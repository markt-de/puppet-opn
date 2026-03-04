# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_hasync) do
  desc <<-DOC
    Manages HA sync (XMLRPC/CARP) settings on an OPNsense device via the
    OPNsense REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. The `config` hash
    is passed directly to the OPNsense API without modification.

    @example Configure HA sync
      opn_hasync { 'opnsense.example.com':
        ensure => present,
        config => {
          'pfsyncenabled'    => '1',
          'pfsyncinterface'  => 'lan',
          'synchronizetoip'  => '10.0.0.2',
          'username'         => 'root',
          'password'         => 'secret',
        },
      }

    @example Disable HA sync
      opn_hasync { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  # Singleton type with deep_match insync?. The 'password' field is excluded
  # from comparison because OPNsense does not return it in plaintext.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of HA sync configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        pfsyncenabled    - Enable pfsync (1 or 0)
        pfsyncinterface  - Interface for pfsync traffic
        pfsyncversion    - pfsync protocol version
        synchronizetoip  - IP of the sync peer
        username         - Sync user
        password         - Sync password (excluded from idempotency check)
        syncitems        - Items to synchronize

      The 'password' field is excluded from idempotency comparison because
      OPNsense does not return it in plaintext.

      Refer to OPNsense HA documentation for all valid keys and values.
    DOC
    singleton: true,
    insync_mode: :deep_match,
    password_fields: ['password'])
end
