# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_kea_dhcpv4_subnet) do
  desc <<-DOC
    Manages KEA DHCPv4 subnets on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "subnet_cidr@device_name", where
    "subnet_cidr" is the CIDR notation (e.g. '192.168.1.0/24') that uniquely
    identifies the subnet and "device_name" corresponds to a YAML config file
    managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    The subnet CIDR has a UniqueConstraint in the OPNsense model, so it serves
    as the natural identifier. Reservations autorequire their parent subnet.

    @example Create a DHCPv4 subnet
      opn_kea_dhcpv4_subnet { '192.168.1.0/24@opnsense.example.com':
        ensure => present,
        config => {
          'description'             => 'LAN DHCP',
          'option_data_autocollect' => '1',
          'option_data'             => {
            'routers'              => '192.168.1.1',
            'domain_name_servers'  => '8.8.8.8,8.8.4.4',
            'domain_name'          => 'example.com',
          },
          'pools' => '192.168.1.100 - 192.168.1.200',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "subnet_cidr@device_name" format.
      The subnet_cidr must be a valid CIDR notation (e.g. '192.168.1.0/24')
      that uniquely identifies the subnet on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of DHCPv4 subnet configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        description             - Human-readable description
        option_data_autocollect - Auto-collect option data from interface (1/0)
        next_server             - TFTP next-server address
        match-client-id         - Match on client-id (1/0)
        option_data             - Hash of DHCP options (routers, domain_name_servers, ...)
        pools                   - Pool range (e.g. '192.168.1.100 - 192.168.1.200')

      Refer to OPNsense KEA documentation for all valid keys and values.
    DOC
    insync_mode: :deep_match)
end
