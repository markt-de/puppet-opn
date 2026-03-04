# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_tunable) do
  desc <<-DOC
    Manages system tunables (sysctl) on an OPNsense device via the OPNsense
    REST API.

    The resource title uses the format "tunable@device_name", where "tunable"
    is the sysctl variable name (e.g. "kern.maxproc") and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Set a system tunable
      opn_tunable { 'kern.maxproc@opnsense.example.com':
        ensure => present,
        config => {
          'value'       => '4096',
          'description' => 'Maximum number of processes',
        },
      }
  DOC

  # Volatile fields are API-generated / read-only and excluded from
  # insync? comparison: tunable (set from title), default_value and type
  # (read-only system information).
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "tunable@device_name" format.
      The "tunable" portion (before "@") is the sysctl variable name.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of tunable configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        value       - The tunable value
        description - Human-readable description

      Volatile fields (excluded from idempotency checks):
        tunable       - Set from the resource title
        default_value - Read-only system default
        type          - Read-only type information

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    volatile_fields: ['tunable', 'default_value', 'type'])
end
