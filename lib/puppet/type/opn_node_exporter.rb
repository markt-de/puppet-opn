# frozen_string_literal: true

Puppet::Type.newtype(:opn_node_exporter) do
  desc <<-DOC
    Manages Prometheus Node Exporter settings on an OPNsense device via the
    OPNsense REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. The `config` hash
    is passed directly to the OPNsense API without modification.

    @example Configure Node Exporter
      opn_node_exporter { 'opnsense.example.com':
        ensure => present,
        config => {
          'enabled'       => '1',
          'listenaddress' => '0.0.0.0',
          'listenport'    => '9100',
          'cpu'           => '1',
          'exec'          => '1',
          'filesystem'    => '1',
          'loadavg'       => '1',
          'meminfo'       => '1',
          'netdev'        => '1',
          'time'          => '1',
          'devstat'       => '1',
          'interrupts'    => '0',
          'ntp'           => '0',
          'zfs'           => '1',
        },
      }

    @example Disable Node Exporter
      opn_node_exporter { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC

    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, 'Name must be a non-empty string'
      end
    end
  end

  newproperty(:config) do
    desc <<-DOC
      A hash of Node Exporter configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        enabled       - Enable node_exporter (1 or 0)
        listenaddress - Listen address (default: 0.0.0.0)
        listenport    - Listen port (default: 9100)
        cpu           - Enable CPU collector (1 or 0)
        exec          - Enable exec collector (1 or 0)
        filesystem    - Enable filesystem collector (1 or 0)
        loadavg       - Enable loadavg collector (1 or 0)
        meminfo       - Enable meminfo collector (1 or 0)
        netdev        - Enable netdev collector (1 or 0)
        time          - Enable time collector (1 or 0)
        devstat       - Enable devstat collector (1 or 0)
        interrupts    - Enable interrupts collector (1 or 0)
        ntp           - Enable NTP collector (1 or 0)
        zfs           - Enable ZFS collector (1 or 0)

      Refer to OPNsense Node Exporter documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      deep_match?(is, should)
    end

    def deep_match?(is_val, should_val)
      return false unless is_val.is_a?(Hash) && should_val.is_a?(Hash)

      should_val.all? do |k, v|
        if v.is_a?(Hash)
          deep_match?(is_val[k], v)
        else
          is_val[k].to_s == v.to_s
        end
      end
    end

    def is_to_s(current_value)
      current_value.inspect
    end

    def should_to_s(new_value)
      new_value.inspect
    end
  end
end
