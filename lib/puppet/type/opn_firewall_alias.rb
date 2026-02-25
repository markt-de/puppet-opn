# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_firewall_alias) do
  desc <<-DOC
    Manages firewall aliases on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "alias_name@device_name", where
    "device_name" corresponds to a YAML config file managed by the opn class
    at /etc/puppet/opn/<device_name>.yaml.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Port alias
      opn_firewall_alias { 'http_ports@opnsense.example.com':
        ensure => present,
        config => {
          'type'        => 'port',
          'content'     => '80,443',
          'description' => 'HTTP(S) ports',
          'enabled'     => '1',
        },
      }

    @example Network alias
      opn_firewall_alias { 'mgmt_nets@opnsense.example.com':
        ensure => present,
        config => {
          'type'    => 'network',
          'content' => '10.0.0.0/8\n192.168.0.0/16',
          'enabled' => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "alias_name@device_name" format.
      The alias_name must match a valid OPNsense alias name.
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
      A hash of alias configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        type        - Alias type (host, network, port, url, urltable, geoip, etc.)
        content     - Alias content (newline-separated values as a single string)
        description - Human-readable description
        proto       - IP protocol filter (IPv4, IPv6, or empty for both)
        updatefreq  - Update frequency for URL table aliases
        counters    - Enable per-alias statistics (0 or 1)
        enabled     - Whether the alias is enabled (1 or 0)

      Refer to OPNsense documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    # Partial comparison: only keys specified in the desired state are compared.
    # Additional fields returned by the API (e.g. uuid, counters) are ignored
    # if not explicitly set in the Puppet manifest.
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
    device = self[:device]
    ["/etc/puppet/opn/#{device}.yaml"]
  end
end
