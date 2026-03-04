# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_remote) do
  desc <<-DOC
    Manages IPsec remote authentication entries on an OPNsense device via the
    OPNsense REST API (Swanctl/MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the remote auth entry and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Relation fields (connection, pubkeys) accept names which are automatically
    resolved to UUIDs via the IdResolver.

    @example Create an IPsec remote authentication
      opn_ipsec_remote { 'remote-auth@opnsense.example.com':
        ensure => present,
        config => {
          'connection' => 'site-to-site',
          'auth'       => 'pubkey',
          'id'         => 'CN=remote.example.com',
          'pubkeys'    => 'remote-keypair',
          'enabled'    => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the remote auth entry on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec remote authentication configuration options passed
      directly to the OPNsense API. Validation is performed by the OPNsense
      API, not Puppet.

      Relation fields (resolved by name):
        connection - IPsec connection description (single)
        pubkeys    - IPsec key pair names (comma-separated)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['description'],
    autorequires: {
      opn_ipsec_connection: { field: 'connection' },
      opn_ipsec_keypair: { field: 'pubkeys', multiple: true },
    })
end
