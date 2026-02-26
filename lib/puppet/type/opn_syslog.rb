# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_syslog) do
  desc <<-DOC
    Manages syslog destinations on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the syslog destination and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Note: The description must be unique per device. Two syslog destinations
    with the same description on the same device will cause unpredictable
    behaviour.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Forward logs to a remote syslog server
      opn_syslog { 'Central syslog@opnsense.example.com':
        ensure => present,
        config => {
          'transport' => 'udp4',
          'hostname'  => 'syslog.example.com',
          'port'      => '514',
          'level'     => 'info,notice,warn,err,crit,alert,emerg',
          'enabled'   => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "description@device_name" format.
      The description must uniquely identify the syslog destination on the device.
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
      A hash of syslog destination configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        transport   - Transport protocol (udp4, tcp4, udp6, tcp6, tls4, tls6)
        hostname    - Remote syslog server hostname or IP
        port        - Remote syslog port
        level       - Comma-separated log levels
        facility    - Comma-separated facilities
        program     - Comma-separated programs to filter
        certificate - Client certificate (for TLS)
        enabled     - Whether the destination is active (1 or 0)

      Refer to OPNsense documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'description' }.all? do |key, value|
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
