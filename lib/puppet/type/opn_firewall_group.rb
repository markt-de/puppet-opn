# frozen_string_literal: true

require 'puppet_x/opn/api_client'

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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "ifname@device_name" format.
      The ifname is the interface group name used in firewall rules.
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

  newproperty(:config) do
    desc <<-DOC
      A hash of interface group configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        members  - Comma-separated list of member interface names
        descr    - Human-readable description
        nogroup  - Exclude from group (0 or 1)
        sequence - Sort order

      Refer to OPNsense documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    # Partial comparison: only keys specified in the desired state are compared.
    def insync?(is)
      return false unless is.is_a?(Hash)

      should.all? do |key, value|
        is[key].to_s == value.to_s
      end
    end

    def is_to_s(current_value)
      current_value.inspect
    end

    def should_to_s(new_value)
      new_value.inspect
    end
  end

  autorequire(:file) do
    device = self[:device]
    ["/etc/puppet/opn/#{device}.yaml"]
  end
end
