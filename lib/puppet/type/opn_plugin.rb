# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_plugin) do
  desc <<-DOC
    Manages plugins/packages on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "plugin_name@device_name", where
    "device_name" corresponds to a YAML config file managed by the opn class
    at /etc/puppet/opn/<device_name>.yaml.

    Plugin names follow the OPNsense package naming convention (e.g. "os-haproxy",
    "os-acme-client", "os-zerotier"). The OPNsense firmware API handles
    installation and removal; no additional configuration is required.

    Note: Install/remove operations are executed immediately but may take some
    time to complete on the OPNsense device (package manager runs asynchronously).

    @example Install HAProxy plugin
      opn_plugin { 'os-haproxy@opnsense.example.com':
        ensure => present,
      }

    @example Remove a plugin
      opn_plugin { 'os-acme-client@opnsense.example.com':
        ensure => absent,
      }
  DOC

  # Plugin type has no config property — only ensure + name + device.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "plugin_name@device_name" format.
      The plugin_name must be a valid OPNsense package name.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: nil)
end
