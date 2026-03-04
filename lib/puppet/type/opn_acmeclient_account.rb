# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_acmeclient_account) do
  desc <<-DOC
    Manages ACME Client accounts on an OPNsense device via the OPNsense
    REST API (os-acme-client plugin).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the ACME account and "device_name" corresponds to
    a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Volatile fields (key, statusCode, statusLastUpdate) are only relevant
    after account registration and are excluded from idempotency checks.

    All configuration validation is delegated to the OPNsense API.

    @example Register a Let's Encrypt account
      opn_acmeclient_account { 'le-account@opnsense.example.com':
        ensure => present,
        config => {
          'ca'               => 'letsencrypt',
          'email'            => 'admin@example.com',
          'enabled'          => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The "name" portion (before "@") is the identifier used in the
      OPNsense API as the account's name field.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of ACME account configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Volatile fields (excluded from idempotency checks):
        key, statusCode, statusLastUpdate

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC
    skip_fields: ['name'],
    volatile_fields: ['key', 'statusCode', 'statusLastUpdate'])
end
