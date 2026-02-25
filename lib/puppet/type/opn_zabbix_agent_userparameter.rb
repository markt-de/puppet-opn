# frozen_string_literal: true

Puppet::Type.newtype(:opn_zabbix_agent_userparameter) do
  desc <<-DOC
    Manages Zabbix Agent UserParameter entries on an OPNsense device via the
    OPNsense REST API.

    The resource title uses the format "key@device_name". The "key" portion
    (before "@") is the Zabbix UserParameter key exactly as it will appear in
    the OPNsense/Zabbix configuration (e.g. "custom.uptime" or
    "system.cpu.load[all,avg5]"). It serves as the unique identifier for the
    resource and is always set from the title — specifying a different "key"
    value inside the `config` hash has no effect.

    To rename a userparameter key, rename the resource title. If an existing
    entry must be renamed, declare the old title with `ensure => absent` and
    add a new resource with the new title.

    All other configuration validation is delegated to the OPNsense API.

    Requires the os-zabbix-agent plugin to be installed on the device.

    @example Define a userparameter (key comes from the title, not from config)
      opn_zabbix_agent_userparameter { 'custom.uptime@opnsense.example.com':
        ensure => present,
        config => {
          'enabled'      => '1',
          'command'      => '/usr/bin/uptime',
          'acceptParams' => '0',
        },
      }

    @example Rename a userparameter key
      # Remove the old entry
      opn_zabbix_agent_userparameter { 'custom.uptime@opnsense.example.com':
        ensure => absent,
      }
      # Create the new entry with the new key as the resource title
      opn_zabbix_agent_userparameter { 'custom.uptime[*]@opnsense.example.com':
        ensure => present,
        config => {
          'enabled'      => '1',
          'command'      => '/usr/bin/uptime',
          'acceptParams' => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "userparameter_key@device_name" format.

      The "userparameter_key" portion (before "@") is the Zabbix UserParameter
      key that uniquely identifies the entry in OPNsense. This value is used
      as-is when creating or updating the entry via the API — it is NOT taken
      from the `config` hash. Any "key" value in `config` is ignored.

      To rename a key, declare the old title with `ensure => absent` and create
      a new resource with the desired key in the title.

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
      A hash of userparameter configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The 'key' field is always derived from the resource title (the part before
      '@') and cannot be changed through config. To rename a userparameter key,
      rename the resource title instead. Any 'key' value in config is ignored
      during comparison and overridden on write.

      Keys:
        key          - Optional; must match the resource title key if specified.
        command      - The command to execute
        enabled      - Whether this entry is enabled: '1' or '0'
        acceptParams - Whether the command accepts parameters: '1' or '0'
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      # Exclude 'key': it is always derived from the resource title and
      # overridden in create/flush, so including it would cause an infinite
      # change loop if the user specifies a different value in config.
      should.reject { |k, _| k == 'key' }.all? do |k, v|
        is[k].to_s == v.to_s
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
