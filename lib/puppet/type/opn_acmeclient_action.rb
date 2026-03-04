# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_acmeclient_action) do
  desc <<-DOC
    Manages ACME Client automation actions on an OPNsense device via the
    OPNsense REST API (os-acme-client plugin).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the action and "device_name" corresponds to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    All configuration validation is delegated to the OPNsense API.

    @example Create a restart action
      opn_acmeclient_action { 'restart_haproxy@opnsense.example.com':
        ensure => present,
        config => {
          'type'    => 'configd',
          'configd' => 'haproxy restart',
          'enabled' => '1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The "name" portion (before "@") is the identifier used in the
      OPNsense API as the action's name field.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of ACME action configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC
    skip_fields: ['name'])
end
