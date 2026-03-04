# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_haproxy_cpu) do
  desc <<-DOC
    Manages HAProxy CPU affinity / thread binding on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name". The "name" portion
    (before "@") is the identifier sent to the OPNsense API and must be unique
    per device. It is always set from the title — specifying a different "name"
    value inside the `config` hash has no effect.

    To rename a resource, rename the resource title. If an existing entry must
    be renamed, declare the old title with `ensure => absent` and add a new
    resource with the new title.

    All other configuration validation is delegated to the OPNsense API. The
    `config` hash is passed through to the API without modification.

    @example Define CPU affinity
      opn_haproxy_cpu { 'cpu0@opnsense.example.com':
        ensure => present,
        config => {
          'description' => 'CPU 0 binding',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "cpu_name@device_name" format.

      The "cpu_name" portion (before "@") is the identifier used in the
      OPNsense API as the resource's "name" field. This value is set from
      the title — it is NOT taken from the `config` hash. Any "name" value
      in `config` is ignored.

      To rename a resource, declare the old title with `ensure => absent`
      and create a new resource with the desired name in the title.

      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of CPU affinity configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Refer to OPNsense HAProxy documentation for all valid keys and values.
    DOC
    skip_fields: ['name'])
end
