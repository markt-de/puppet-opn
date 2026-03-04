# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_acmeclient_validation) do
  desc <<-DOC
    Manages ACME Client validation methods on an OPNsense device via the
    OPNsense REST API (os-acme-client plugin).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the validation method and "device_name" corresponds
    to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The relation field http_haproxyFrontends accepts HAProxy frontend names
    which are automatically resolved to UUIDs.

    All configuration validation is delegated to the OPNsense API.

    @example Create an HTTP-01 validation method
      opn_acmeclient_validation { 'http-01@opnsense.example.com':
        ensure => present,
        config => {
          'method'               => 'http01',
          'http_service'         => 'haproxy',
          'http_haproxyFrontends'=> 'https_frontend',
          'enabled'              => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The "name" portion (before "@") is the identifier used in the
      OPNsense API as the validation method's name field.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of ACME validation method configuration options passed directly
      to the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Relation fields (resolved by name):
        http_haproxyFrontends - HAProxy frontend names (comma-separated)

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC
    skip_fields: ['name'],
    autorequires: {
      opn_haproxy_frontend: { field: 'http_haproxyFrontends', multiple: true },
    })
end
