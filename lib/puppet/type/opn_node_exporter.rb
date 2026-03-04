# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

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

  # Singleton type with deep_match insync? — recursive subset comparison
  # where only keys present in should are checked against is.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC
    config_desc: <<-DOC,
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
    singleton: true,
    insync_mode: :deep_match)
end
