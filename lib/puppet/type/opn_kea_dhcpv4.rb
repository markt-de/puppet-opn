# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_dhcpv4) do
  desc <<-DOC
    Manages KEA DHCPv4 global settings on an OPNsense device via the OPNsense
    REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. It manages the
    KEA DHCPv4 'general', 'lexpire' and 'ha' sections. The `config` hash
    is passed directly to the OPNsense API without modification.

    @example Configure KEA DHCPv4 settings
      opn_kea_dhcpv4 { 'opnsense.example.com':
        ensure => present,
        config => {
          'general' => {
            'enabled'          => '1',
            'interfaces'       => 'lan',
            'valid_lifetime'   => '4000',
            'fwrules'          => '1',
            'dhcp_socket_type' => 'raw',
          },
          'lexpire' => {
            'reclaim_timer_wait_time' => '10',
          },
          'ha' => {
            'enabled' => '0',
          },
        },
      }

    @example Disable KEA DHCPv4
      opn_kea_dhcpv4 { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of KEA DHCPv4 configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The structure mirrors the OPNsense KEA DHCPv4 model:
        general - General settings (enabled, interfaces, valid_lifetime, ...)
        lexpire - Lease expiration settings (reclaim_timer_wait_time, ...)
        ha      - High availability settings (enabled, ...)

      Fields with selection hashes (normalized automatically):
        general.interfaces       - InterfaceField
        general.dhcp_socket_type - OptionField

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    singleton: true,
    insync_mode: :deep_match)
end
