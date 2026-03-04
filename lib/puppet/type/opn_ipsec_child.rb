# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_child) do
  desc <<-DOC
    Manages IPsec child SA (Security Association) entries on an OPNsense
    device via the OPNsense REST API (Swanctl/MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the child SA and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The connection relation field accepts a connection description which is
    automatically resolved to a UUID via the IdResolver.

    @example Create an IPsec child SA
      opn_ipsec_child { 'child-lan@opnsense.example.com':
        ensure => present,
        config => {
          'connection'    => 'site-to-site',
          'mode'          => 'tunnel',
          'local_ts'      => '10.0.0.0/24',
          'remote_ts'     => '10.0.1.0/24',
          'esp_proposals' => 'aes256-sha256',
          'enabled'       => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the child SA on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec child SA configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Relation fields (resolved by name):
        connection - IPsec connection description (single)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['description'],
    autorequires: {
      opn_ipsec_connection: { field: 'connection' },
    })
end
