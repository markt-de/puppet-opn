# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_firewall_category) do
  desc <<-DOC
    Manages firewall categories on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "category_name@device_name", where
    "device_name" corresponds to a YAML config file managed by the opn class
    at /etc/puppet/opn/<device_name>.yaml.

    Firewall categories are used to group and organise rules, aliases, and other
    firewall objects. All configuration validation is delegated to the OPNsense API.

    @example Create a firewall category
      opn_firewall_category { 'web_traffic@opnsense.example.com':
        ensure => present,
        config => {
          'color' => '0088cc',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "category_name@device_name" format.
      The category_name must be a valid OPNsense firewall category name.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC)
      A hash of category configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        color - Hex colour code for the category label (e.g. "0088cc")

      Refer to OPNsense documentation for all valid keys and values.
    DOC
end
