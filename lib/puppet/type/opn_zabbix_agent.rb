# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_zabbix_agent) do
  desc <<-DOC
    Manages Zabbix Agent settings on an OPNsense device via the OPNsense REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource — one per OPNsense device. It maps to the
    Zabbix Agent plugin (os-zabbix-agent) settings. The `config` hash is passed
    directly to the OPNsense API without modification.

    Userparameters and aliases are managed by separate resource types:
    opn_zabbix_agent_userparameter and opn_zabbix_agent_alias.

    Requires the os-zabbix-agent plugin to be installed on the device.

    @example Configure Zabbix Agent
      opn_zabbix_agent { 'opnsense.example.com':
        ensure => present,
        config => {
          'settings' => {
            'main' => {
              'enabled'    => '1',
              'serverList' => 'zabbix.example.com',
              'listenPort' => '10050',
            },
          },
        },
      }

    @example Disable Zabbix Agent
      opn_zabbix_agent { 'opnsense.example.com':
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
      A hash of Zabbix Agent configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The structure mirrors the OPNsense ZabbixAgent model:
        settings.main     - Main settings (enabled, serverList, listenPort, ...)
        settings.tuning   - Tuning settings (startAgents, timeout, ...)
        settings.features - Feature settings (enableActiveChecks, encryption, ...)
        local             - Local settings (hostname)

      Refer to OPNsense Zabbix Agent documentation for all valid keys.
    DOC
    singleton: true,
    insync_mode: :deep_match)
end
