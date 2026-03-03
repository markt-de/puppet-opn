# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_openvpn_instance) do
  desc <<-DOC
    Manages OpenVPN instances on an OPNsense device via the OPNsense REST API
    (MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the instance and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The 'password' field is intentionally excluded from idempotency
    comparison because it contains secret material.

    Volatile fields (vpnid) are auto-assigned by OPNsense and excluded from
    idempotency checks.

    The tls_key relation field accepts a static key description which is
    automatically resolved to a UUID via the HaproxyUuidResolver.

    @example Create an OpenVPN server instance
      opn_openvpn_instance { 'roadwarrior-server@opnsense.example.com':
        ensure => present,
        config => {
          'role'           => 'server',
          'proto'          => 'udp',
          'port'           => '1194',
          'server'         => '10.8.0.0/24',
          'tls_key'        => 'my-tls-auth-key',
          'enabled'        => '1',
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
      The description must uniquely identify the instance on the device.
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
      A hash of OpenVPN instance configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      The 'password' field is excluded from idempotency comparison because
      it contains secret material.

      Volatile fields (excluded from idempotency checks):
        vpnid (auto-assigned numeric ID)

      Relation fields (resolved by name):
        tls_key - OpenVPN static key description (single)

      Refer to OPNsense OpenVPN documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      volatile = ['vpnid']
      should.reject { |k, _| k == 'description' || volatile.include?(k) }.all? do |key, value|
        next true if key == 'password'

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

  autorequire(:opn_openvpn_statickey) do
    device = self[:device]
    config = self[:config] || {}
    tls_key = config['tls_key'].to_s.strip
    tls_key.empty? ? [] : ["#{tls_key}@#{device}"]
  end
end
