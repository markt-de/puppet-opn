# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_syslog) do
  desc <<-DOC
    Manages syslog destinations on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the syslog destination and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Note: The description must be unique per device. Two syslog destinations
    with the same description on the same device will cause unpredictable
    behaviour.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Forward logs to a remote syslog server
      opn_syslog { 'Central syslog@opnsense.example.com':
        ensure => present,
        config => {
          'transport' => 'udp4',
          'hostname'  => 'syslog.example.com',
          'port'      => '514',
          'level'     => 'info,notice,warn,err,crit,alert,emerg',
          'enabled'   => '1',
        },
      }
  DOC

  # The 'description' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the syslog destination on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of syslog destination configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        transport   - Transport protocol (udp4, tcp4, udp6, tcp6, tls4, tls6)
        hostname    - Remote syslog server hostname or IP
        port        - Remote syslog port
        level       - Comma-separated log levels
        facility    - Comma-separated facilities
        program     - Comma-separated programs to filter
        certificate - Client certificate (for TLS)
        enabled     - Whether the destination is active (1 or 0)

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    skip_fields: ['description'])
end
