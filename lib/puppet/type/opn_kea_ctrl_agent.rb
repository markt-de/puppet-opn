# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_ctrl_agent) do
  desc <<-DOC
    Manages KEA Control Agent settings on an OPNsense device via the OPNsense
    REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. It manages the
    KEA Control Agent's 'general' section. The `config` hash is passed directly
    to the OPNsense API without modification.

    @example Configure KEA Control Agent
      opn_kea_ctrl_agent { 'opnsense.example.com':
        ensure => present,
        config => {
          'general' => {
            'enabled'   => '1',
            'http_host' => '127.0.0.1',
            'http_port' => '8000',
          },
        },
      }

    @example Disable KEA Control Agent
      opn_kea_ctrl_agent { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of KEA Control Agent configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The structure mirrors the OPNsense KEA Control Agent model:
        general - General settings (enabled, http_host, http_port)

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    singleton: true,
    insync_mode: :deep_match)
end
