# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_settings) do
  desc <<-DOC
    Manages IPsec global settings on an OPNsense device via the OPNsense
    REST API (Swanctl/MVC model).

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. It manages the
    IPsec 'general' and 'charon' sections. The `config` hash is passed
    directly to the OPNsense API without modification.

    @example Configure IPsec global settings
      opn_ipsec_settings { 'opnsense.example.com':
        ensure => present,
        config => {
          'general' => {
            'enabled' => '1',
          },
          'charon' => {
            'threads' => '16',
          },
        },
      }

    @example Disable IPsec
      opn_ipsec_settings { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec global configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      The structure mirrors the OPNsense IPsec model:
        general - Global settings (enabled, etc.)
        charon  - Charon daemon settings (threads, etc.)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    singleton: true,
    insync_mode: :deep_match)
end
