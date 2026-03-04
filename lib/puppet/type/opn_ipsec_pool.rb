# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_pool) do
  desc <<-DOC
    Manages IPsec address pools on an OPNsense device via the OPNsense
    REST API (Swanctl/MVC model).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the pool and "device_name" corresponds to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    @example Create an IPsec pool
      opn_ipsec_pool { 'vpn-pool@opnsense.example.com':
        ensure => present,
        config => {
          'addrs' => '10.10.0.0/24',
          'dns'   => '10.10.0.1',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The name must uniquely identify the pool on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec pool configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['name'])
end
