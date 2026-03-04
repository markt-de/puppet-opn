# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_presharedkey) do
  desc <<-DOC
    Manages IPsec pre-shared keys on an OPNsense device via the OPNsense
    REST API (Swanctl/MVC model).

    The resource title uses the format "ident@device_name", where "ident"
    uniquely identifies the pre-shared key and "device_name" corresponds to
    a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The 'Key' field is intentionally excluded from idempotency comparison
    because it contains the actual pre-shared key secret.

    @example Create an IPsec pre-shared key
      opn_ipsec_presharedkey { 'remote-peer@opnsense.example.com':
        ensure => present,
        config => {
          'keyType' => 'PSK',
          'Key'     => 'supersecretkey',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "ident@device_name" format.
      The ident must uniquely identify the pre-shared key on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec pre-shared key configuration options passed directly
      to the OPNsense API. Validation is performed by the OPNsense API,
      not Puppet.

      The 'Key' field is excluded from idempotency comparison because it
      contains the actual pre-shared key secret.

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['ident'],
    password_fields: ['Key'])
end
