# frozen_string_literal: true

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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "plugin_name@device_name" format.
      The plugin_name must be a valid OPNsense package name.
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

  autorequire(:file) do
    device = self[:device]
    ["/etc/puppet/opn/#{device}.yaml"]
  end
end
