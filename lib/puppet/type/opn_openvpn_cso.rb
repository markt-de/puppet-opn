# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_openvpn_cso) do
  desc <<-DOC
    Manages OpenVPN client-specific overrides (CSO) on an OPNsense device
    via the OPNsense REST API (MVC model).

    The resource title uses the format "common_name@device_name", where
    "common_name" uniquely identifies the override entry and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The servers relation field accepts instance descriptions which are
    automatically resolved to UUIDs via the HaproxyUuidResolver.

    @example Create an OpenVPN client override
      opn_openvpn_cso { 'client1@opnsense.example.com':
        ensure => present,
        config => {
          'servers'          => 'roadwarrior-server',
          'tunnel_network'   => '10.8.1.0/24',
          'local_network'    => '192.168.1.0/24',
          'enabled'          => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "common_name@device_name" format.
      The common_name must uniquely identify the CSO entry on the device.
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
      A hash of OpenVPN CSO configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Relation fields (resolved by name):
        servers - OpenVPN instance descriptions (comma-separated)

      Refer to OPNsense OpenVPN documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'common_name' }.all? do |key, value|
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

  autorequire(:opn_openvpn_instance) do
    device = self[:device]
    config = self[:config] || {}
    config['servers'].to_s.split(',').map(&:strip).reject(&:empty?)
                     .map { |s| "#{s}@#{device}" }
  end
end
