# frozen_string_literal: true

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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC

    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, 'Name must be a non-empty string'
      end
    end
  end

  newproperty(:config) do
    desc <<-DOC
      A hash of Zabbix Agent configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The structure mirrors the OPNsense ZabbixAgent model:
        settings.main     - Main settings (enabled, serverList, listenPort, ...)
        settings.tuning   - Tuning settings (startAgents, timeout, ...)
        settings.features - Feature settings (enableActiveChecks, encryption, ...)
        local             - Local settings (hostname)

      Refer to OPNsense Zabbix Agent documentation for all valid keys.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      deep_match?(is, should)
    end

    # Recursively checks that every key/value in +should_val+ matches
    # the corresponding entry in +is_val+. Keys present in +is_val+ but
    # absent from +should_val+ are ignored (subset match).
    def deep_match?(is_val, should_val)
      return false unless is_val.is_a?(Hash) && should_val.is_a?(Hash)

      should_val.all? do |k, v|
        if v.is_a?(Hash)
          deep_match?(is_val[k], v)
        else
          is_val[k].to_s == v.to_s
        end
      end
    end

    def is_to_s(current_value)
      current_value.inspect
    end

    def should_to_s(new_value)
      new_value.inspect
    end
  end

  autorequire(:file) do
    ["/etc/puppet/opn/#{self[:name]}.yaml"]
  end
end
