# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_firewall_rule) do
  desc <<-DOC
    Manages firewall filter rules on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the rule and "device_name" corresponds to a
    YAML config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    Note: The description must be unique per device. Two rules with the same
    description on the same device will cause unpredictable behaviour.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Allow HTTP and HTTPS traffic
      opn_firewall_rule { 'Allow HTTP(S)@opnsense.example.com':
        ensure => present,
        config => {
          'action'          => 'pass',
          'interface'       => 'lan',
          'ipprotocol'      => 'inet',
          'protocol'        => 'tcp',
          'source_net'      => 'any',
          'destination_net' => 'any',
          'destination_port'=> '80,443',
          'enabled'         => '1',
        },
      }

    @example Block traffic from a specific host
      opn_firewall_rule { 'Block suspicious host@opnsense.example.com':
        ensure => present,
        config => {
          'action'     => 'block',
          'interface'  => 'wan',
          'source_net' => '203.0.113.42',
          'enabled'    => '1',
          'log'        => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "description@device_name" format.
      The description must uniquely identify the rule on the device.
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
      A hash of rule configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        action          - Rule action: pass, block, or reject
        interface       - Interface name(s) the rule applies to
        direction       - Traffic direction: in or out
        ipprotocol      - IP version: inet (IPv4), inet6 (IPv6)
        protocol        - Protocol: any, tcp, udp, icmp, etc.
        source_net      - Source address or alias
        source_not      - Invert source match (0 or 1)
        source_port     - Source port or range
        destination_net - Destination address or alias
        destination_not - Invert destination match (0 or 1)
        destination_port- Destination port or range
        gateway         - Gateway for policy routing
        enabled         - Whether the rule is active (1 or 0)
        log             - Enable logging (1 or 0)
        sequence        - Rule sort order
        quick           - Stop processing further rules on match (1 or 0)

      Refer to OPNsense documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    # Partial comparison: only keys specified in the desired state are compared.
    # API-only fields (e.g. sort_order, prio_group, %action) are ignored.
    # Comparison is case-insensitive because OPNsense normalises some values
    # to uppercase (e.g. protocol "tcp" is stored and returned as "TCP").
    def insync?(is)
      return false unless is.is_a?(Hash)

      should.all? do |key, value|
        is[key].to_s.casecmp(value.to_s).zero?
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
