# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_ipsec_connection) do
  desc <<-DOC
    Manages IPsec connections on an OPNsense device via the OPNsense REST API
    (Swanctl/MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the connection and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Volatile fields (local_ts, remote_ts) are computed from children and
    excluded from idempotency checks.

    @example Create an IPsec connection
      opn_ipsec_connection { 'site-to-site@opnsense.example.com':
        ensure => present,
        config => {
          'version'    => '2',
          'proposals'  => 'aes256-sha256-modp2048',
          'local_addrs' => '0.0.0.0/0',
          'remote_addrs' => '198.51.100.1',
          'enabled'    => '1',
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
      The description must uniquely identify the connection on the device.
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
      A hash of IPsec connection configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Volatile fields (excluded from idempotency checks):
        local_ts, remote_ts (computed from children)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      volatile = ['local_ts', 'remote_ts']
      should.reject { |k, _| k == 'description' || volatile.include?(k) }.all? do |key, value|
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
end
