# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_firewall_group) do
  desc <<-DOC
    Manages firewall interface groups on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "ifname@device_name", where "ifname" is the
    interface group name and "device_name" corresponds to a YAML config file managed
    by the opn class at /etc/puppet/opn/<device_name>.yaml.

    System-managed interface groups (e.g. enc0/IPsec, openvpn, wireguard) are not
    managed by this type and are automatically skipped during catalog prefetch.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create a firewall interface group
      opn_firewall_group { 'dmz_servers@opnsense.example.com':
        ensure => present,
        config => {
          'members'  => 'em1,em2',
          'descr'    => 'DMZ server interfaces',
          'sequence' => '10',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "ifname@device_name" format.
      The ifname is the interface group name used in firewall rules.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC)
      A hash of interface group configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        members  - Comma-separated list of member interface names
        descr    - Human-readable description
        nogroup  - Exclude from group (0 or 1)
        sequence - Sort order

      Refer to OPNsense documentation for all valid keys and values.
    DOC
end
