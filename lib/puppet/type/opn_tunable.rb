# frozen_string_literal: true

require 'puppet_x/opn/api_client'

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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "tunable@device_name" format.
      The "tunable" portion (before "@") is the sysctl variable name.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC

    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, 'Name must be a non-empty string'
      end
    end
  end

  newparam(:device) do
    desc <<-DOC
      The OPNsense device name. If not explicitly set, it is extracted
      from the resource title (the part after the last "@" character).
      Falls back to "default" if no "@" is present in the title.
    DOC

    defaultto do
      title = @resource[:name]
      title.include?('@') ? title.split('@', 2).last : 'default'
    end
  end

  newproperty(:config) do
    desc <<-DOC
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

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      volatile = ['tunable', 'default_value', 'type']
      should.reject { |k, _| volatile.include?(k) }.all? do |key, value|
        is[key].to_s == value.to_s
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
    device = self[:device]
    ["/etc/puppet/opn/#{device}.yaml"]
  end
end
