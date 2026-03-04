# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

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

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "alias_name@device_name" format.
      The alias_name must match a valid OPNsense alias name.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC)
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
end
