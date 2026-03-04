# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_acmeclient_certificate) do
  desc <<-DOC
    Manages ACME Client certificates on an OPNsense device via the OPNsense
    REST API (os-acme-client plugin).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the certificate and "device_name" corresponds to
    a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Relation fields (account, validationMethod, restartActions) accept names
    which are automatically resolved to UUIDs via the IdResolver.

    Volatile fields (certRefId, lastUpdate, statusCode, statusLastUpdate)
    are excluded from idempotency checks.

    @example Request a certificate
      opn_acmeclient_certificate { 'web.example.com@opnsense.example.com':
        ensure => present,
        config => {
          'altNames'         => 'www.example.com',
          'account'          => 'le-account',
          'validationMethod' => 'http-01',
          'restartActions'   => 'restart_haproxy',
          'enabled'          => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The "name" portion (before "@") is the identifier used in the
      OPNsense API as the certificate's name field.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of ACME certificate configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Relation fields (resolved by name):
        account          - ACME account name (single)
        validationMethod - Validation method name (single)
        restartActions   - Automation action names (comma-separated)

      Volatile fields (excluded from idempotency checks):
        certRefId, lastUpdate, statusCode, statusLastUpdate

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC
    skip_fields: ['name'],
    volatile_fields: ['certRefId', 'lastUpdate', 'statusCode', 'statusLastUpdate'],
    autorequires: {
      opn_acmeclient_account: { field: 'account' },
      opn_acmeclient_validation: { field: 'validationMethod' },
      opn_acmeclient_action: { field: 'restartActions', multiple: true },
    })
end
