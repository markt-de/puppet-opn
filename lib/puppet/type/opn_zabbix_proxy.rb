# frozen_string_literal: true

Puppet::Type.newtype(:opn_zabbix_proxy) do
  desc <<-DOC
    Manages Zabbix Proxy settings on an OPNsense device via the OPNsense REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource — one per OPNsense device. It maps to the
    Zabbix Proxy plugin (os-zabbix-proxy) general settings. The `config` hash
    is passed directly to the OPNsense API without modification.

    Requires the os-zabbix-proxy plugin to be installed on the device.

    @example Configure Zabbix Proxy
      opn_zabbix_proxy { 'opnsense.example.com':
        ensure => present,
        config => {
          'enabled'    => '1',
          'server'     => 'zabbix.example.com',
          'serverport' => '10051',
          'hostname'   => 'opnsense-proxy',
        },
      }

    @example Disable Zabbix Proxy
      opn_zabbix_proxy { 'opnsense.example.com':
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
      A hash of Zabbix Proxy configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Common keys (see OPNsense Zabbix Proxy documentation for all valid keys):
        enabled         - Enable the proxy: '1' or '0'
        server          - Zabbix server hostname or IP
        serverport      - Zabbix server port (default: 10051)
        hostname        - Proxy hostname as known in Zabbix
        proxymode       - Active (0) or passive (1) proxy mode
        encryption      - Enable encryption: '1' or '0'
        encryptionidentity - PSK identity string
        encryptionpsk   - PSK value (hex string)
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.all? do |key, value|
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
    ["/etc/puppet/opn/#{self[:name]}.yaml"]
  end
end
