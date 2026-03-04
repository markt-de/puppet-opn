# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_openvpn_statickey) do
  desc <<-DOC
    Manages OpenVPN static keys on an OPNsense device via the OPNsense
    REST API (MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the static key and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    @example Create an OpenVPN static key
      opn_openvpn_statickey { 'my-tls-auth-key@opnsense.example.com':
        ensure => present,
        config => {
          'mode' => 'auth',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the static key on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of OpenVPN static key configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Refer to OPNsense OpenVPN documentation for all valid keys and values.
    DOC
    skip_fields: ['description'])
end
