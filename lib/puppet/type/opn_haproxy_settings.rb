# frozen_string_literal: true

Puppet::Type.newtype(:opn_haproxy_settings) do
  desc <<-DOC
    Manages HAProxy global settings on an OPNsense device via the OPNsense
    REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. It manages the
    HAProxy plugin's 'general' and 'maintenance' sections. The `config` hash
    is passed directly to the OPNsense API without modification.

    Cron job references in maintenance.cronjobs are resolved by description.
    User/group references in general.stats are resolved by name.

    Requires the os-haproxy plugin to be installed on the device.

    @example Configure HAProxy global settings
      opn_haproxy_settings { 'opnsense.example.com':
        ensure => present,
        config => {
          'general' => {
            'enabled' => '1',
            'stats'   => {
              'enabled'       => '1',
              'allowedUsers'  => 'haproxy_admin',
              'allowedGroups' => 'stats_viewers',
            },
          },
          'maintenance' => {
            'cronjobs' => {
              'syncCertsCron' => 'HAProxy: sync certificates',
            },
          },
        },
      }

    @example Disable HAProxy
      opn_haproxy_settings { 'opnsense.example.com':
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
      A hash of HAProxy global configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The structure mirrors the OPNsense HAProxy model:
        general          - Global settings (enabled, tuning, logging, stats, ...)
        maintenance      - Maintenance settings (cronjobs)

      Cron job fields (maintenance.cronjobs.*) accept cron job descriptions
      which are automatically resolved to UUIDs.

      User/group fields (general.stats.allowedUsers/allowedGroups) accept
      HAProxy user/group names which are automatically resolved to UUIDs.

      Refer to OPNsense HAProxy documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      deep_match?(is, should)
    end

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
