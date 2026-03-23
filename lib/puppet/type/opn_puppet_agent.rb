# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_puppet_agent) do
  desc <<-DOC
    Manages Puppet Agent settings on an OPNsense device via the OPNsense
    REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. The `config` hash
    is passed directly to the OPNsense API without modification.

    @example Configure Puppet Agent
      opn_puppet_agent { 'opnsense.example.com':
        ensure => present,
        config => {
          'enabled'            => '1',
          'fqdn'               => 'puppet.example.com',
          'environment'        => 'production',
          'runinterval'        => '30m',
          'runtimeout'         => '1h',
          'usecacheonfailure'  => '1',
        },
      }

    @example Disable Puppet Agent
      opn_puppet_agent { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  # Singleton type with deep_match insync? — recursive subset comparison
  # where only keys present in should are checked against is.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of Puppet Agent configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        enabled            - Enable Puppet Agent (1 or 0)
        fqdn               - Puppet server FQDN (default: puppet)
        environment        - Puppet environment (default: production)
        runinterval        - Run interval (default: 30m)
        runtimeout         - Run timeout (default: 1h)
        usecacheonfailure  - Use cached catalog on failure (1 or 0)

      Refer to OPNsense Puppet Agent documentation for all valid keys and values.
    DOC
    singleton: true,
    insync_mode: :deep_match)
end
