# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_acmeclient_settings) do
  desc <<-DOC
    Manages ACME Client global settings on an OPNsense device via the
    OPNsense REST API (os-acme-client plugin).

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. The `config` hash
    is passed directly to the OPNsense API without modification.

    Relation fields (UpdateCron, haproxyAclRef, haproxyActionRef,
    haproxyServerRef, haproxyBackendRef) accept names which are automatically
    resolved to UUIDs.

    After any settings change, Puppet calls `acmeclient/service/reconfigure`
    once per device.

    @example Configure ACME Client settings
      opn_acmeclient_settings { 'opnsense.example.com':
        ensure => present,
        config => {
          'environment' => 'stg',
          'logLevel'    => 'normal',
          'autoRenewal' => '1',
          'UpdateCron'  => 'ACME renew cron',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of ACME Client settings passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not Puppet.

      Relation fields (resolved by name):
        UpdateCron       - Cron job description (single)
        haproxyAclRef    - HAProxy ACL name (single)
        haproxyActionRef - HAProxy action name (single)
        haproxyServerRef - HAProxy server name (single)
        haproxyBackendRef- HAProxy backend name (single)

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC
    singleton: true,
    autorequires: {
      opn_cron: { field: 'UpdateCron' },
      opn_haproxy_acl: { field: 'haproxyAclRef' },
      opn_haproxy_action: { field: 'haproxyActionRef' },
      opn_haproxy_server: { field: 'haproxyServerRef' },
      opn_haproxy_backend: { field: 'haproxyBackendRef' },
    })
end
