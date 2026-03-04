# @summary Manages OPNsense firewalls via the REST API.
#
# This class is the main entry point for the puppet-opn module. It delegates
# provider configuration (config directory, credential files) to opn::config
# and creates opn_* resources for one or more OPNsense devices.
#
# @param acmeclient_accounts
#   Hash of ACME Client accounts to manage across devices.
#   Each key is the account name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_account.
#
# @param acmeclient_actions
#   Hash of ACME Client automation actions to manage across devices.
#   Each key is the action name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_action.
#
# @param acmeclient_certificates
#   Hash of ACME Client certificates to manage across devices.
#   Each key is the certificate name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_certificate.
#
# @param acmeclient_settings
#   Hash of ACME Client global settings, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_settings.
#
# @param acmeclient_validations
#   Hash of ACME Client validation methods to manage across devices.
#   Each key is the validation method name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_validation.
#
# @param cron_jobs
#   Hash of cron jobs to manage across devices.
#   Each key is the cron job description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_cron.
#
# @param dhcrelay_destinations
#   Hash of DHCP Relay destinations to manage across devices.
#   Each key is the destination name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_dhcrelay_destination.
#
# @param dhcrelays
#   Hash of DHCP Relay instances to manage across devices.
#   Each key is a freeform label (not sent to the API).
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_dhcrelay.
#
# @param devices
#   Hash of OPNsense devices to manage. Each key is the device name used as
#   suffix in opn_* resource titles (format: "resource@device_name").
#   Each value is a hash with connection parameters:
#     - url        [String]  OPNsense API base URL
#     - api_key    [String]  OPNsense API key (required)
#     - api_secret [String]  OPNsense API secret (required)
#     - ssl_verify [Boolean] Verify SSL certificate (default: true)
#     - timeout    [Integer] HTTP timeout in seconds (default: 60)
#
# @param firewall_aliases
#   Hash of firewall aliases to manage across devices.
#   Each key is the alias name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_alias.
#
# @param firewall_categories
#   Hash of firewall categories to manage across devices.
#   Each key is the category name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_category.
#
# @param firewall_groups
#   Hash of firewall interface groups to manage across devices.
#   Each key is the interface group name (ifname).
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_group.
#
# @param firewall_rules
#   Hash of firewall filter rules to manage across devices.
#   Each key is the rule description (must be unique per device).
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_rule.
#
# @param gateways
#   Hash of gateways to manage across devices.
#   Each key is the gateway name (e.g. 'WAN_GW').
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_gateway.
#
# @param groups
#   Hash of local groups to manage across devices.
#   Each key is the group name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_group.
#
# @param haproxy_acls
#   Hash of HAProxy ACL rules to manage across devices.
#   Each key is the ACL name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_acl.
#
# @param haproxy_actions
#   Hash of HAProxy actions to manage across devices.
#   Each key is the action name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_action.
#
# @param haproxy_backends
#   Hash of HAProxy backends to manage across devices.
#   Each key is the backend name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_backend.
#
# @param haproxy_cpus
#   Hash of HAProxy CPU affinity entries to manage across devices.
#   Each key is the CPU entry name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_cpu.
#
# @param haproxy_errorfiles
#   Hash of HAProxy error files to manage across devices.
#   Each key is the error file name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_errorfile.
#
# @param haproxy_fcgis
#   Hash of HAProxy FastCGI applications to manage across devices.
#   Each key is the FastCGI application name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_fcgi.
#
# @param haproxy_frontends
#   Hash of HAProxy frontends to manage across devices.
#   Each key is the frontend name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_frontend.
#
# @param haproxy_groups
#   Hash of HAProxy user-list groups to manage across devices.
#   Each key is the group name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_group.
#
# @param haproxy_healthchecks
#   Hash of HAProxy health checks to manage across devices.
#   Each key is the health check name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_healthcheck.
#
# @param haproxy_luas
#   Hash of HAProxy Lua scripts to manage across devices.
#   Each key is the Lua script name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_lua.
#
# @param haproxy_mailers
#   Hash of HAProxy mailers to manage across devices.
#   Each key is the mailer name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_mailer.
#
# @param haproxy_mapfiles
#   Hash of HAProxy map files to manage across devices.
#   Each key is the map file name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_mapfile.
#
# @param haproxy_resolvers
#   Hash of HAProxy DNS resolvers to manage across devices.
#   Each key is the resolver name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_resolver.
#
# @param haproxy_servers
#   Hash of HAProxy backend servers to manage across devices.
#   Each key is the server name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_server.
#
# @param haproxy_settings
#   Hash of HAProxy global settings, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_settings.
#
# @param haproxy_users
#   Hash of HAProxy user-list users to manage across devices.
#   Each key is the user name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_user.
#
# @param hasyncs
#   Hash of HA sync configurations, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_hasync.
#
# @param ipsec_children
#   Hash of IPsec child SAs to manage across devices.
#   Each key is the child SA description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_child.
#
# @param ipsec_connections
#   Hash of IPsec connections to manage across devices.
#   Each key is the connection description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_connection.
#
# @param ipsec_keypairs
#   Hash of IPsec key pairs to manage across devices.
#   Each key is the key pair name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_keypair.
#
# @param ipsec_locals
#   Hash of IPsec local authentication entries to manage across devices.
#   Each key is the local auth description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_local.
#
# @param ipsec_pools
#   Hash of IPsec address pools to manage across devices.
#   Each key is the pool name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_pool.
#
# @param ipsec_presharedkeys
#   Hash of IPsec pre-shared keys to manage across devices.
#   Each key is the PSK identifier.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_presharedkey.
#
# @param ipsec_remotes
#   Hash of IPsec remote authentication entries to manage across devices.
#   Each key is the remote auth description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_remote.
#
# @param ipsec_settings
#   Hash of IPsec global settings, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_settings.
#
# @param ipsec_vtis
#   Hash of IPsec VTI entries to manage across devices.
#   Each key is the VTI description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_ipsec_vti.
#
# @param kea_ctrl_agents
#   Hash of KEA Control Agent settings, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_ctrl_agent.
#
# @param kea_dhcpv4_peers
#   Hash of KEA DHCPv4 HA peers to manage across devices.
#   Each key is the peer name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv4_peer.
#
# @param kea_dhcpv4_reservations
#   Hash of KEA DHCPv4 reservations to manage across devices.
#   Each key is the reservation description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv4_reservation.
#
# @param kea_dhcpv4_subnets
#   Hash of KEA DHCPv4 subnets to manage across devices.
#   Each key is the subnet CIDR (e.g. '192.168.1.0/24').
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv4_subnet.
#
# @param kea_dhcpv4s
#   Hash of KEA DHCPv4 global settings, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv4.
#
# @param kea_dhcpv6_pd_pools
#   Hash of KEA DHCPv6 prefix delegation pools to manage across devices.
#   Each key is the PD pool description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv6_pd_pool.
#
# @param kea_dhcpv6_peers
#   Hash of KEA DHCPv6 HA peers to manage across devices.
#   Each key is the peer name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv6_peer.
#
# @param kea_dhcpv6_reservations
#   Hash of KEA DHCPv6 reservations to manage across devices.
#   Each key is the reservation description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv6_reservation.
#
# @param kea_dhcpv6_subnets
#   Hash of KEA DHCPv6 subnets to manage across devices.
#   Each key is the subnet CIDR (e.g. 'fd00::/64').
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv6_subnet.
#
# @param kea_dhcpv6s
#   Hash of KEA DHCPv6 global settings, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_kea_dhcpv6.
#
# @param manage_resources
#   Boolean to enable collection of exported opn_* resources from client nodes
#   via PuppetDB. When true, the class collects all exported opn_* resources
#   tagged with the device name. Default: false.
#
# @param node_exporters
#   Hash of Node Exporter configurations, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_node_exporter.
#
# @param openvpn_csos
#   Hash of OpenVPN client-specific overrides to manage across devices.
#   Each key is the client common name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_openvpn_cso.
#
# @param openvpn_instances
#   Hash of OpenVPN instances to manage across devices.
#   Each key is the instance description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_openvpn_instance.
#
# @param openvpn_statickeys
#   Hash of OpenVPN static keys to manage across devices.
#   Each key is the static key description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_openvpn_statickey.
#
# @param plugins
#   Hash of plugins to manage across devices.
#   Each key is the plugin package name (e.g. 'os-haproxy').
#   Each value is a hash with:
#     - devices [Array] List of device names to manage the plugin on.
#                       Defaults to all devices in $devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#
# @param routes
#   Hash of static routes to manage across devices.
#   Each key is the route description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_route.
#
# @param snapshots
#   Hash of ZFS snapshots to manage across devices.
#   Each key is the snapshot name.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - active  [Boolean] Whether snapshot is the active boot target.
#     - All other keys are passed as the 'config' hash to opn_snapshot.
#
# @param syslog_destinations
#   Hash of syslog destinations to manage across devices.
#   Each key is the syslog destination description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_syslog.
#
# @param trust_cas
#   Hash of trust CAs to manage across devices.
#   Each key is the CA description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_trust_ca.
#
# @param trust_certs
#   Hash of trust certificates to manage across devices.
#   Each key is the certificate description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_trust_cert.
#
# @param trust_crls
#   Hash of trust CRLs to manage across devices.
#   Each key is the CA description the CRL belongs to.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_trust_crl.
#
# @param tunables
#   Hash of system tunables to manage across devices.
#   Each key is the sysctl variable name (e.g. 'kern.maxproc').
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_tunable.
#
# @param users
#   Hash of local users to manage across devices.
#   Each key is the username.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_user.
#
# @param zabbix_agent_aliases
#   Hash of Zabbix Agent Alias entries to manage across devices.
#   Each key is the alias key.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_zabbix_agent_alias.
#
# @param zabbix_agent_userparameters
#   Hash of Zabbix Agent UserParameter entries to manage across devices.
#   Each key is the userparameter key.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_zabbix_agent_userparameter.
#
# @param zabbix_agents
#   Hash of Zabbix Agent configurations, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_zabbix_agent.
#
# @param zabbix_proxies
#   Hash of Zabbix Proxy configurations, one per device.
#   Each key is the device name (not a "name@device" title).
#   Each value is a hash with:
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_zabbix_proxy.
#
# @example Single device with plugins and aliases
#   class { 'opn':
#     devices => {
#       'opnsense.example.com' => {
#         'url'        => 'https://opnsense.example.com/api',
#         'api_key'    => 'your_api_key_here',
#         'api_secret' => 'your_api_secret_here',
#         'ssl_verify' => true,
#       },
#     },
#     plugins => {
#       'os-haproxy' => {
#         'devices' => ['opnsense.example.com'],
#         'ensure'  => 'present',
#       },
#     },
#     firewall_aliases => {
#       'http_ports' => {
#         'devices'     => ['opnsense.example.com'],
#         'ensure'      => 'present',
#         'type'        => 'port',
#         'content'     => '80,443',
#         'description' => 'HTTP(S) ports',
#         'enabled'     => '1',
#       },
#     },
#   }
#
class opn (
  Hash                 $acmeclient_accounts,
  Hash                 $acmeclient_actions,
  Hash                 $acmeclient_certificates,
  Hash                 $acmeclient_settings,
  Hash                 $acmeclient_validations,
  Hash                 $cron_jobs,
  Hash                 $dhcrelay_destinations,
  Hash                 $dhcrelays,
  Hash                 $devices,
  Hash                 $firewall_aliases,
  Hash                 $firewall_categories,
  Hash                 $firewall_groups,
  Hash                 $firewall_rules,
  Hash                 $gateways,
  Hash                 $groups,
  Hash                 $haproxy_acls,
  Hash                 $haproxy_actions,
  Hash                 $haproxy_backends,
  Hash                 $haproxy_cpus,
  Hash                 $haproxy_errorfiles,
  Hash                 $haproxy_fcgis,
  Hash                 $haproxy_frontends,
  Hash                 $haproxy_groups,
  Hash                 $haproxy_healthchecks,
  Hash                 $haproxy_luas,
  Hash                 $haproxy_mailers,
  Hash                 $haproxy_mapfiles,
  Hash                 $haproxy_resolvers,
  Hash                 $haproxy_servers,
  Hash                 $haproxy_settings,
  Hash                 $haproxy_users,
  Hash                 $hasyncs,
  Hash                 $ipsec_children,
  Hash                 $ipsec_connections,
  Hash                 $ipsec_keypairs,
  Hash                 $ipsec_locals,
  Hash                 $ipsec_pools,
  Hash                 $ipsec_presharedkeys,
  Hash                 $ipsec_remotes,
  Hash                 $ipsec_settings,
  Hash                 $ipsec_vtis,
  Hash                 $kea_ctrl_agents,
  Hash                 $kea_dhcpv4_peers,
  Hash                 $kea_dhcpv4_reservations,
  Hash                 $kea_dhcpv4_subnets,
  Hash                 $kea_dhcpv4s,
  Hash                 $kea_dhcpv6_pd_pools,
  Hash                 $kea_dhcpv6_peers,
  Hash                 $kea_dhcpv6_reservations,
  Hash                 $kea_dhcpv6_subnets,
  Hash                 $kea_dhcpv6s,
  Boolean              $manage_resources,
  Hash                 $node_exporters,
  Hash                 $openvpn_csos,
  Hash                 $openvpn_instances,
  Hash                 $openvpn_statickeys,
  Hash                 $plugins,
  Hash                 $routes,
  Hash                 $snapshots,
  Hash                 $syslog_destinations,
  Hash                 $trust_cas,
  Hash                 $trust_certs,
  Hash                 $trust_crls,
  Hash                 $tunables,
  Hash                 $users,
  Hash                 $zabbix_agent_aliases,
  Hash                 $zabbix_agent_userparameters,
  Hash                 $zabbix_agents,
  Hash                 $zabbix_proxies,
) {
  class { 'opn::config':
    devices => $devices,
  }
  contain 'opn::config'

  # Manage ACME Client accounts across devices
  $acmeclient_accounts.each |String $item_name, Hash $item_options| {
    $acme_account_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $acme_account_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_account_config = $item_options - ['devices', 'ensure']

    $acme_account_devices.each |String $device_name| {
      opn_acmeclient_account { "${item_name}@${device_name}":
        ensure  => $acme_account_ensure,
        config  => $acme_account_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage ACME Client automation actions across devices
  $acmeclient_actions.each |String $item_name, Hash $item_options| {
    $acme_action_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $acme_action_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_action_config = $item_options - ['devices', 'ensure']

    $acme_action_devices.each |String $device_name| {
      opn_acmeclient_action { "${item_name}@${device_name}":
        ensure  => $acme_action_ensure,
        config  => $acme_action_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage ACME Client certificates across devices
  $acmeclient_certificates.each |String $item_name, Hash $item_options| {
    $acme_cert_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $acme_cert_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_cert_config = $item_options - ['devices', 'ensure']

    $acme_cert_devices.each |String $device_name| {
      opn_acmeclient_certificate { "${item_name}@${device_name}":
        ensure  => $acme_cert_ensure,
        config  => $acme_cert_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage ACME Client settings per device (singleton per device)
  $acmeclient_settings.each |String $device_name, Hash $settings_options| {
    $acme_settings_ensure = 'ensure' in $settings_options ? {
      true    => $settings_options['ensure'],
      default => 'present',
    }
    $acme_settings_config = $settings_options - ['ensure']

    opn_acmeclient_settings { $device_name:
      ensure  => $acme_settings_ensure,
      config  => $acme_settings_config,
      require => Class['opn::config'],
    }
  }

  # Manage ACME Client validation methods across devices
  $acmeclient_validations.each |String $item_name, Hash $item_options| {
    $acme_validation_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $acme_validation_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_validation_config = $item_options - ['devices', 'ensure']

    $acme_validation_devices.each |String $device_name| {
      opn_acmeclient_validation { "${item_name}@${device_name}":
        ensure  => $acme_validation_ensure,
        config  => $acme_validation_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage cron jobs across devices
  $cron_jobs.each |String $job_desc, Hash $job_options| {
    $job_devices = 'devices' in $job_options ? {
      true    => $job_options['devices'],
      default => keys($devices),
    }
    $job_ensure = 'ensure' in $job_options ? {
      true    => $job_options['ensure'],
      default => 'present',
    }
    $job_config = $job_options - ['devices', 'ensure']

    $job_devices.each |String $device_name| {
      opn_cron { "${job_desc}@${device_name}":
        ensure  => $job_ensure,
        config  => $job_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage DHCP Relay destinations across devices
  $dhcrelay_destinations.each |String $item_name, Hash $item_options| {
    $dhcrelay_dest_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $dhcrelay_dest_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $dhcrelay_dest_config = $item_options - ['devices', 'ensure']

    $dhcrelay_dest_devices.each |String $device_name| {
      opn_dhcrelay_destination { "${item_name}@${device_name}":
        ensure  => $dhcrelay_dest_ensure,
        config  => $dhcrelay_dest_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage DHCP Relay instances across devices
  $dhcrelays.each |String $item_name, Hash $item_options| {
    $dhcrelay_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $dhcrelay_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $dhcrelay_config = $item_options - ['devices', 'ensure']

    $dhcrelay_devices.each |String $device_name| {
      opn_dhcrelay { "${item_name}@${device_name}":
        ensure  => $dhcrelay_ensure,
        config  => $dhcrelay_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage firewall aliases across devices
  $firewall_aliases.each |String $alias_name, Hash $alias_options| {
    $alias_devices = 'devices' in $alias_options ? {
      true    => $alias_options['devices'],
      default => keys($devices),
    }
    $alias_ensure = 'ensure' in $alias_options ? {
      true    => $alias_options['ensure'],
      default => 'present',
    }
    $alias_config = $alias_options - ['devices', 'ensure']

    $alias_devices.each |String $device_name| {
      opn_firewall_alias { "${alias_name}@${device_name}":
        ensure  => $alias_ensure,
        config  => $alias_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage firewall categories across devices
  $firewall_categories.each |String $cat_name, Hash $cat_options| {
    $cat_devices = 'devices' in $cat_options ? {
      true    => $cat_options['devices'],
      default => keys($devices),
    }
    $cat_ensure = 'ensure' in $cat_options ? {
      true    => $cat_options['ensure'],
      default => 'present',
    }
    $cat_config = $cat_options - ['devices', 'ensure']

    $cat_devices.each |String $device_name| {
      opn_firewall_category { "${cat_name}@${device_name}":
        ensure  => $cat_ensure,
        config  => $cat_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage firewall interface groups across devices
  $firewall_groups.each |String $fwgroup_name, Hash $fwgroup_options| {
    $fwgroup_devices = 'devices' in $fwgroup_options ? {
      true    => $fwgroup_options['devices'],
      default => keys($devices),
    }
    $fwgroup_ensure = 'ensure' in $fwgroup_options ? {
      true    => $fwgroup_options['ensure'],
      default => 'present',
    }
    $fwgroup_config = $fwgroup_options - ['devices', 'ensure']

    $fwgroup_devices.each |String $device_name| {
      opn_firewall_group { "${fwgroup_name}@${device_name}":
        ensure  => $fwgroup_ensure,
        config  => $fwgroup_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage firewall filter rules across devices
  $firewall_rules.each |String $rule_desc, Hash $rule_options| {
    $rule_devices = 'devices' in $rule_options ? {
      true    => $rule_options['devices'],
      default => keys($devices),
    }
    $rule_ensure = 'ensure' in $rule_options ? {
      true    => $rule_options['ensure'],
      default => 'present',
    }
    $rule_config = $rule_options - ['devices', 'ensure']

    $rule_devices.each |String $device_name| {
      opn_firewall_rule { "${rule_desc}@${device_name}":
        ensure  => $rule_ensure,
        config  => $rule_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage gateways across devices
  $gateways.each |String $gw_name, Hash $gw_options| {
    $gw_devices = 'devices' in $gw_options ? {
      true    => $gw_options['devices'],
      default => keys($devices),
    }
    $gw_ensure = 'ensure' in $gw_options ? {
      true    => $gw_options['ensure'],
      default => 'present',
    }
    $gw_config = $gw_options - ['devices', 'ensure']

    $gw_devices.each |String $device_name| {
      opn_gateway { "${gw_name}@${device_name}":
        ensure  => $gw_ensure,
        config  => $gw_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage local groups across devices
  $groups.each |String $group_name, Hash $group_options| {
    $group_devices = 'devices' in $group_options ? {
      true    => $group_options['devices'],
      default => keys($devices),
    }
    $group_ensure = 'ensure' in $group_options ? {
      true    => $group_options['ensure'],
      default => 'present',
    }
    $group_config = $group_options - ['devices', 'ensure']

    $group_devices.each |String $device_name| {
      opn_group { "${group_name}@${device_name}":
        ensure  => $group_ensure,
        config  => $group_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy ACLs across devices
  $haproxy_acls.each |String $item_name, Hash $item_options| {
    $haproxy_acl_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_acl_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_acl_config = $item_options - ['devices', 'ensure']

    $haproxy_acl_devices.each |String $device_name| {
      opn_haproxy_acl { "${item_name}@${device_name}":
        ensure  => $haproxy_acl_ensure,
        config  => $haproxy_acl_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy actions across devices
  $haproxy_actions.each |String $item_name, Hash $item_options| {
    $haproxy_action_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_action_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_action_config = $item_options - ['devices', 'ensure']

    $haproxy_action_devices.each |String $device_name| {
      opn_haproxy_action { "${item_name}@${device_name}":
        ensure  => $haproxy_action_ensure,
        config  => $haproxy_action_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy backends across devices
  $haproxy_backends.each |String $item_name, Hash $item_options| {
    $haproxy_backend_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_backend_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_backend_config = $item_options - ['devices', 'ensure']

    $haproxy_backend_devices.each |String $device_name| {
      opn_haproxy_backend { "${item_name}@${device_name}":
        ensure  => $haproxy_backend_ensure,
        config  => $haproxy_backend_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy CPU affinity entries across devices
  $haproxy_cpus.each |String $item_name, Hash $item_options| {
    $haproxy_cpu_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_cpu_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_cpu_config = $item_options - ['devices', 'ensure']

    $haproxy_cpu_devices.each |String $device_name| {
      opn_haproxy_cpu { "${item_name}@${device_name}":
        ensure  => $haproxy_cpu_ensure,
        config  => $haproxy_cpu_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy error files across devices
  $haproxy_errorfiles.each |String $item_name, Hash $item_options| {
    $haproxy_errorfile_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_errorfile_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_errorfile_config = $item_options - ['devices', 'ensure']

    $haproxy_errorfile_devices.each |String $device_name| {
      opn_haproxy_errorfile { "${item_name}@${device_name}":
        ensure  => $haproxy_errorfile_ensure,
        config  => $haproxy_errorfile_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy FastCGI applications across devices
  $haproxy_fcgis.each |String $item_name, Hash $item_options| {
    $haproxy_fcgi_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_fcgi_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_fcgi_config = $item_options - ['devices', 'ensure']

    $haproxy_fcgi_devices.each |String $device_name| {
      opn_haproxy_fcgi { "${item_name}@${device_name}":
        ensure  => $haproxy_fcgi_ensure,
        config  => $haproxy_fcgi_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy frontends across devices
  $haproxy_frontends.each |String $item_name, Hash $item_options| {
    $haproxy_frontend_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_frontend_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_frontend_config = $item_options - ['devices', 'ensure']

    $haproxy_frontend_devices.each |String $device_name| {
      opn_haproxy_frontend { "${item_name}@${device_name}":
        ensure  => $haproxy_frontend_ensure,
        config  => $haproxy_frontend_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy user-list groups across devices
  $haproxy_groups.each |String $item_name, Hash $item_options| {
    $haproxy_group_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_group_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_group_config = $item_options - ['devices', 'ensure']

    $haproxy_group_devices.each |String $device_name| {
      opn_haproxy_group { "${item_name}@${device_name}":
        ensure  => $haproxy_group_ensure,
        config  => $haproxy_group_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy health checks across devices
  $haproxy_healthchecks.each |String $item_name, Hash $item_options| {
    $haproxy_healthcheck_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_healthcheck_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_healthcheck_config = $item_options - ['devices', 'ensure']

    $haproxy_healthcheck_devices.each |String $device_name| {
      opn_haproxy_healthcheck { "${item_name}@${device_name}":
        ensure  => $haproxy_healthcheck_ensure,
        config  => $haproxy_healthcheck_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy Lua scripts across devices
  $haproxy_luas.each |String $item_name, Hash $item_options| {
    $haproxy_lua_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_lua_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_lua_config = $item_options - ['devices', 'ensure']

    $haproxy_lua_devices.each |String $device_name| {
      opn_haproxy_lua { "${item_name}@${device_name}":
        ensure  => $haproxy_lua_ensure,
        config  => $haproxy_lua_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy mailers across devices
  $haproxy_mailers.each |String $item_name, Hash $item_options| {
    $haproxy_mailer_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_mailer_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_mailer_config = $item_options - ['devices', 'ensure']

    $haproxy_mailer_devices.each |String $device_name| {
      opn_haproxy_mailer { "${item_name}@${device_name}":
        ensure  => $haproxy_mailer_ensure,
        config  => $haproxy_mailer_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy map files across devices
  $haproxy_mapfiles.each |String $item_name, Hash $item_options| {
    $haproxy_mapfile_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_mapfile_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_mapfile_config = $item_options - ['devices', 'ensure']

    $haproxy_mapfile_devices.each |String $device_name| {
      opn_haproxy_mapfile { "${item_name}@${device_name}":
        ensure  => $haproxy_mapfile_ensure,
        config  => $haproxy_mapfile_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy DNS resolvers across devices
  $haproxy_resolvers.each |String $item_name, Hash $item_options| {
    $haproxy_resolver_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_resolver_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_resolver_config = $item_options - ['devices', 'ensure']

    $haproxy_resolver_devices.each |String $device_name| {
      opn_haproxy_resolver { "${item_name}@${device_name}":
        ensure  => $haproxy_resolver_ensure,
        config  => $haproxy_resolver_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy servers across devices
  $haproxy_servers.each |String $item_name, Hash $item_options| {
    $haproxy_server_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_server_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_server_config = $item_options - ['devices', 'ensure']

    $haproxy_server_devices.each |String $device_name| {
      opn_haproxy_server { "${item_name}@${device_name}":
        ensure  => $haproxy_server_ensure,
        config  => $haproxy_server_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HAProxy global settings per device (singleton per device)
  $haproxy_settings.each |String $device_name, Hash $settings_options| {
    $haproxy_settings_ensure = 'ensure' in $settings_options ? {
      true    => $settings_options['ensure'],
      default => 'present',
    }
    $haproxy_settings_config = $settings_options - ['ensure']

    opn_haproxy_settings { $device_name:
      ensure  => $haproxy_settings_ensure,
      config  => $haproxy_settings_config,
      require => Class['opn::config'],
    }
  }

  # Manage HAProxy user-list users across devices
  $haproxy_users.each |String $item_name, Hash $item_options| {
    $haproxy_user_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $haproxy_user_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_user_config = $item_options - ['devices', 'ensure']

    $haproxy_user_devices.each |String $device_name| {
      opn_haproxy_user { "${item_name}@${device_name}":
        ensure  => $haproxy_user_ensure,
        config  => $haproxy_user_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage HA sync settings per device (singleton per device)
  $hasyncs.each |String $device_name, Hash $hasync_options| {
    $hasync_ensure = 'ensure' in $hasync_options ? {
      true    => $hasync_options['ensure'],
      default => 'present',
    }
    $hasync_config = $hasync_options - ['ensure']

    opn_hasync { $device_name:
      ensure  => $hasync_ensure,
      config  => $hasync_config,
      require => Class['opn::config'],
    }
  }

  # Manage IPsec child SAs across devices
  $ipsec_children.each |String $item_name, Hash $item_options| {
    $ipsec_child_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_child_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_child_config = $item_options - ['devices', 'ensure']

    $ipsec_child_devices.each |String $device_name| {
      opn_ipsec_child { "${item_name}@${device_name}":
        ensure  => $ipsec_child_ensure,
        config  => $ipsec_child_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec connections across devices
  $ipsec_connections.each |String $item_name, Hash $item_options| {
    $ipsec_conn_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_conn_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_conn_config = $item_options - ['devices', 'ensure']

    $ipsec_conn_devices.each |String $device_name| {
      opn_ipsec_connection { "${item_name}@${device_name}":
        ensure  => $ipsec_conn_ensure,
        config  => $ipsec_conn_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec key pairs across devices
  $ipsec_keypairs.each |String $item_name, Hash $item_options| {
    $ipsec_kp_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_kp_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_kp_config = $item_options - ['devices', 'ensure']

    $ipsec_kp_devices.each |String $device_name| {
      opn_ipsec_keypair { "${item_name}@${device_name}":
        ensure  => $ipsec_kp_ensure,
        config  => $ipsec_kp_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec local authentication entries across devices
  $ipsec_locals.each |String $item_name, Hash $item_options| {
    $ipsec_local_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_local_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_local_config = $item_options - ['devices', 'ensure']

    $ipsec_local_devices.each |String $device_name| {
      opn_ipsec_local { "${item_name}@${device_name}":
        ensure  => $ipsec_local_ensure,
        config  => $ipsec_local_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec address pools across devices
  $ipsec_pools.each |String $item_name, Hash $item_options| {
    $ipsec_pool_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_pool_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_pool_config = $item_options - ['devices', 'ensure']

    $ipsec_pool_devices.each |String $device_name| {
      opn_ipsec_pool { "${item_name}@${device_name}":
        ensure  => $ipsec_pool_ensure,
        config  => $ipsec_pool_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec pre-shared keys across devices
  $ipsec_presharedkeys.each |String $item_name, Hash $item_options| {
    $ipsec_psk_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_psk_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_psk_config = $item_options - ['devices', 'ensure']

    $ipsec_psk_devices.each |String $device_name| {
      opn_ipsec_presharedkey { "${item_name}@${device_name}":
        ensure  => $ipsec_psk_ensure,
        config  => $ipsec_psk_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec remote authentication entries across devices
  $ipsec_remotes.each |String $item_name, Hash $item_options| {
    $ipsec_remote_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_remote_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_remote_config = $item_options - ['devices', 'ensure']

    $ipsec_remote_devices.each |String $device_name| {
      opn_ipsec_remote { "${item_name}@${device_name}":
        ensure  => $ipsec_remote_ensure,
        config  => $ipsec_remote_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage IPsec global settings per device (singleton per device)
  $ipsec_settings.each |String $device_name, Hash $settings_options| {
    $ipsec_settings_ensure = 'ensure' in $settings_options ? {
      true    => $settings_options['ensure'],
      default => 'present',
    }
    $ipsec_settings_config = $settings_options - ['ensure']

    opn_ipsec_settings { $device_name:
      ensure  => $ipsec_settings_ensure,
      config  => $ipsec_settings_config,
      require => Class['opn::config'],
    }
  }

  # Manage IPsec VTI entries across devices
  $ipsec_vtis.each |String $item_name, Hash $item_options| {
    $ipsec_vti_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ipsec_vti_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ipsec_vti_config = $item_options - ['devices', 'ensure']

    $ipsec_vti_devices.each |String $device_name| {
      opn_ipsec_vti { "${item_name}@${device_name}":
        ensure  => $ipsec_vti_ensure,
        config  => $ipsec_vti_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA Control Agent settings per device (singleton per device)
  $kea_ctrl_agents.each |String $device_name, Hash $kca_options| {
    $kca_ensure = 'ensure' in $kca_options ? {
      true    => $kca_options['ensure'],
      default => 'present',
    }
    $kca_config = $kca_options - ['ensure']

    opn_kea_ctrl_agent { $device_name:
      ensure  => $kca_ensure,
      config  => $kca_config,
      require => Class['opn::config'],
    }
  }

  # Manage KEA DHCPv4 HA peers across devices
  $kea_dhcpv4_peers.each |String $item_name, Hash $item_options| {
    $kd4p_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd4p_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd4p_config = $item_options - ['devices', 'ensure']

    $kd4p_devices.each |String $device_name| {
      opn_kea_dhcpv4_peer { "${item_name}@${device_name}":
        ensure  => $kd4p_ensure,
        config  => $kd4p_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv4 reservations across devices
  $kea_dhcpv4_reservations.each |String $item_name, Hash $item_options| {
    $kd4r_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd4r_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd4r_config = $item_options - ['devices', 'ensure']

    $kd4r_devices.each |String $device_name| {
      opn_kea_dhcpv4_reservation { "${item_name}@${device_name}":
        ensure  => $kd4r_ensure,
        config  => $kd4r_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv4 subnets across devices
  $kea_dhcpv4_subnets.each |String $item_name, Hash $item_options| {
    $kd4s_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd4s_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd4s_config = $item_options - ['devices', 'ensure']

    $kd4s_devices.each |String $device_name| {
      opn_kea_dhcpv4_subnet { "${item_name}@${device_name}":
        ensure  => $kd4s_ensure,
        config  => $kd4s_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv4 global settings per device (singleton per device)
  $kea_dhcpv4s.each |String $device_name, Hash $kd4_options| {
    $kd4_ensure = 'ensure' in $kd4_options ? {
      true    => $kd4_options['ensure'],
      default => 'present',
    }
    $kd4_config = $kd4_options - ['ensure']

    opn_kea_dhcpv4 { $device_name:
      ensure  => $kd4_ensure,
      config  => $kd4_config,
      require => Class['opn::config'],
    }
  }

  # Manage KEA DHCPv6 prefix delegation pools across devices
  $kea_dhcpv6_pd_pools.each |String $item_name, Hash $item_options| {
    $kd6pd_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd6pd_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd6pd_config = $item_options - ['devices', 'ensure']

    $kd6pd_devices.each |String $device_name| {
      opn_kea_dhcpv6_pd_pool { "${item_name}@${device_name}":
        ensure  => $kd6pd_ensure,
        config  => $kd6pd_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv6 HA peers across devices
  $kea_dhcpv6_peers.each |String $item_name, Hash $item_options| {
    $kd6p_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd6p_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd6p_config = $item_options - ['devices', 'ensure']

    $kd6p_devices.each |String $device_name| {
      opn_kea_dhcpv6_peer { "${item_name}@${device_name}":
        ensure  => $kd6p_ensure,
        config  => $kd6p_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv6 reservations across devices
  $kea_dhcpv6_reservations.each |String $item_name, Hash $item_options| {
    $kd6r_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd6r_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd6r_config = $item_options - ['devices', 'ensure']

    $kd6r_devices.each |String $device_name| {
      opn_kea_dhcpv6_reservation { "${item_name}@${device_name}":
        ensure  => $kd6r_ensure,
        config  => $kd6r_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv6 subnets across devices
  $kea_dhcpv6_subnets.each |String $item_name, Hash $item_options| {
    $kd6s_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $kd6s_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $kd6s_config = $item_options - ['devices', 'ensure']

    $kd6s_devices.each |String $device_name| {
      opn_kea_dhcpv6_subnet { "${item_name}@${device_name}":
        ensure  => $kd6s_ensure,
        config  => $kd6s_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage KEA DHCPv6 global settings per device (singleton per device)
  $kea_dhcpv6s.each |String $device_name, Hash $kd6_options| {
    $kd6_ensure = 'ensure' in $kd6_options ? {
      true    => $kd6_options['ensure'],
      default => 'present',
    }
    $kd6_config = $kd6_options - ['ensure']

    opn_kea_dhcpv6 { $device_name:
      ensure  => $kd6_ensure,
      config  => $kd6_config,
      require => Class['opn::config'],
    }
  }

  # Manage Node Exporter settings per device (singleton per device)
  $node_exporters.each |String $device_name, Hash $ne_options| {
    $ne_ensure = 'ensure' in $ne_options ? {
      true    => $ne_options['ensure'],
      default => 'present',
    }
    $ne_config = $ne_options - ['ensure']

    opn_node_exporter { $device_name:
      ensure  => $ne_ensure,
      config  => $ne_config,
      require => Class['opn::config'],
    }
  }

  # Manage OpenVPN client-specific overrides across devices
  $openvpn_csos.each |String $item_name, Hash $item_options| {
    $ovpn_cso_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ovpn_cso_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ovpn_cso_config = $item_options - ['devices', 'ensure']

    $ovpn_cso_devices.each |String $device_name| {
      opn_openvpn_cso { "${item_name}@${device_name}":
        ensure  => $ovpn_cso_ensure,
        config  => $ovpn_cso_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage OpenVPN instances across devices
  $openvpn_instances.each |String $item_name, Hash $item_options| {
    $ovpn_inst_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ovpn_inst_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ovpn_inst_config = $item_options - ['devices', 'ensure']

    $ovpn_inst_devices.each |String $device_name| {
      opn_openvpn_instance { "${item_name}@${device_name}":
        ensure  => $ovpn_inst_ensure,
        config  => $ovpn_inst_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage OpenVPN static keys across devices
  $openvpn_statickeys.each |String $item_name, Hash $item_options| {
    $ovpn_sk_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $ovpn_sk_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $ovpn_sk_config = $item_options - ['devices', 'ensure']

    $ovpn_sk_devices.each |String $device_name| {
      opn_openvpn_statickey { "${item_name}@${device_name}":
        ensure  => $ovpn_sk_ensure,
        config  => $ovpn_sk_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage plugins across devices
  $plugins.each |String $plugin_name, Hash $plugin_options| {
    $plugin_devices = 'devices' in $plugin_options ? {
      true    => $plugin_options['devices'],
      default => keys($devices),
    }
    $plugin_ensure = 'ensure' in $plugin_options ? {
      true    => $plugin_options['ensure'],
      default => 'present',
    }

    $plugin_devices.each |String $device_name| {
      opn_plugin { "${plugin_name}@${device_name}":
        ensure  => $plugin_ensure,
        require => Class['opn::config'],
      }
    }
  }

  # Manage static routes across devices
  $routes.each |String $route_desc, Hash $route_options| {
    $route_devices = 'devices' in $route_options ? {
      true    => $route_options['devices'],
      default => keys($devices),
    }
    $route_ensure = 'ensure' in $route_options ? {
      true    => $route_options['ensure'],
      default => 'present',
    }
    $route_config = $route_options - ['devices', 'ensure']

    $route_devices.each |String $device_name| {
      opn_route { "${route_desc}@${device_name}":
        ensure  => $route_ensure,
        config  => $route_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage ZFS snapshots across devices
  $snapshots.each |String $snap_name, Hash $snap_options| {
    $snap_devices = 'devices' in $snap_options ? {
      true    => $snap_options['devices'],
      default => keys($devices),
    }
    $snap_ensure = 'ensure' in $snap_options ? {
      true    => $snap_options['ensure'],
      default => 'present',
    }
    $snap_active = 'active' in $snap_options ? {
      true    => $snap_options['active'],
      default => undef,
    }
    $snap_config = $snap_options - ['devices', 'ensure', 'active']

    $snap_devices.each |String $device_name| {
      opn_snapshot { "${snap_name}@${device_name}":
        ensure  => $snap_ensure,
        active  => $snap_active,
        config  => $snap_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage syslog destinations across devices
  $syslog_destinations.each |String $dest_desc, Hash $dest_options| {
    $dest_devices = 'devices' in $dest_options ? {
      true    => $dest_options['devices'],
      default => keys($devices),
    }
    $dest_ensure = 'ensure' in $dest_options ? {
      true    => $dest_options['ensure'],
      default => 'present',
    }
    $dest_config = $dest_options - ['devices', 'ensure']

    $dest_devices.each |String $device_name| {
      opn_syslog { "${dest_desc}@${device_name}":
        ensure  => $dest_ensure,
        config  => $dest_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage trust CAs across devices
  $trust_cas.each |String $ca_descr, Hash $ca_options| {
    $ca_devices = 'devices' in $ca_options ? {
      true    => $ca_options['devices'],
      default => keys($devices),
    }
    $ca_ensure = 'ensure' in $ca_options ? {
      true    => $ca_options['ensure'],
      default => 'present',
    }
    $ca_config = $ca_options - ['devices', 'ensure']

    $ca_devices.each |String $device_name| {
      opn_trust_ca { "${ca_descr}@${device_name}":
        ensure  => $ca_ensure,
        config  => $ca_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage trust certificates across devices
  $trust_certs.each |String $cert_descr, Hash $cert_options| {
    $cert_devices = 'devices' in $cert_options ? {
      true    => $cert_options['devices'],
      default => keys($devices),
    }
    $cert_ensure = 'ensure' in $cert_options ? {
      true    => $cert_options['ensure'],
      default => 'present',
    }
    $cert_config = $cert_options - ['devices', 'ensure']

    $cert_devices.each |String $device_name| {
      opn_trust_cert { "${cert_descr}@${device_name}":
        ensure  => $cert_ensure,
        config  => $cert_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage trust CRLs across devices
  $trust_crls.each |String $crl_ca_descr, Hash $crl_options| {
    $crl_devices = 'devices' in $crl_options ? {
      true    => $crl_options['devices'],
      default => keys($devices),
    }
    $crl_ensure = 'ensure' in $crl_options ? {
      true    => $crl_options['ensure'],
      default => 'present',
    }
    $crl_config = $crl_options - ['devices', 'ensure']

    $crl_devices.each |String $device_name| {
      opn_trust_crl { "${crl_ca_descr}@${device_name}":
        ensure  => $crl_ensure,
        config  => $crl_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage system tunables across devices
  $tunables.each |String $tunable_key, Hash $tunable_options| {
    $tunable_devices = 'devices' in $tunable_options ? {
      true    => $tunable_options['devices'],
      default => keys($devices),
    }
    $tunable_ensure = 'ensure' in $tunable_options ? {
      true    => $tunable_options['ensure'],
      default => 'present',
    }
    $tunable_config = $tunable_options - ['devices', 'ensure']

    $tunable_devices.each |String $device_name| {
      opn_tunable { "${tunable_key}@${device_name}":
        ensure  => $tunable_ensure,
        config  => $tunable_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage local users across devices
  $users.each |String $user_name, Hash $user_options| {
    $user_devices = 'devices' in $user_options ? {
      true    => $user_options['devices'],
      default => keys($devices),
    }
    $user_ensure = 'ensure' in $user_options ? {
      true    => $user_options['ensure'],
      default => 'present',
    }
    $user_config = $user_options - ['devices', 'ensure']

    $user_devices.each |String $device_name| {
      opn_user { "${user_name}@${device_name}":
        ensure  => $user_ensure,
        config  => $user_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage Zabbix Agent aliases across devices
  $zabbix_agent_aliases.each |String $item_name, Hash $item_options| {
    $zabbix_alias_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $zabbix_alias_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $zabbix_alias_config = $item_options - ['devices', 'ensure']

    $zabbix_alias_devices.each |String $device_name| {
      opn_zabbix_agent_alias { "${item_name}@${device_name}":
        ensure  => $zabbix_alias_ensure,
        config  => $zabbix_alias_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage Zabbix Agent userparameters across devices
  $zabbix_agent_userparameters.each |String $item_name, Hash $item_options| {
    $zabbix_up_devices = 'devices' in $item_options ? {
      true    => $item_options['devices'],
      default => keys($devices),
    }
    $zabbix_up_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $zabbix_up_config = $item_options - ['devices', 'ensure']

    $zabbix_up_devices.each |String $device_name| {
      opn_zabbix_agent_userparameter { "${item_name}@${device_name}":
        ensure  => $zabbix_up_ensure,
        config  => $zabbix_up_config,
        require => Class['opn::config'],
      }
    }
  }

  # Manage Zabbix Agent settings per device (singleton per device)
  $zabbix_agents.each |String $device_name, Hash $agent_options| {
    $zabbix_agent_ensure = 'ensure' in $agent_options ? {
      true    => $agent_options['ensure'],
      default => 'present',
    }
    $zabbix_agent_config = $agent_options - ['ensure']

    opn_zabbix_agent { $device_name:
      ensure  => $zabbix_agent_ensure,
      config  => $zabbix_agent_config,
      require => Class['opn::config'],
    }
  }

  # Manage Zabbix Proxy settings per device (singleton per device)
  $zabbix_proxies.each |String $device_name, Hash $proxy_options| {
    $zabbix_proxy_ensure = 'ensure' in $proxy_options ? {
      true    => $proxy_options['ensure'],
      default => 'present',
    }
    $zabbix_proxy_config = $proxy_options - ['ensure']

    opn_zabbix_proxy { $device_name:
      ensure  => $zabbix_proxy_ensure,
      config  => $zabbix_proxy_config,
      require => Class['opn::config'],
    }
  }

  # Collect exported opn_* resources from client nodes
  if $manage_resources {
    $devices.each |String $device_name, Hash $_device_config| {
      Opn_acmeclient_account <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_acmeclient_action <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_acmeclient_certificate <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_acmeclient_validation <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_cron <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_dhcrelay_destination <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_dhcrelay <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_firewall_alias <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_firewall_category <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_firewall_group <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_firewall_rule <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_gateway <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_group <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_child <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_connection <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_keypair <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_local <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_pool <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_presharedkey <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_remote <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_ipsec_vti <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv4_peer <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv4_reservation <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv4_subnet <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv6_pd_pool <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv6_peer <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv6_reservation <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_kea_dhcpv6_subnet <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_acl <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_action <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_backend <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_cpu <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_errorfile <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_fcgi <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_frontend <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_group <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_healthcheck <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_lua <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_mailer <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_mapfile <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_resolver <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_server <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_haproxy_user <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_openvpn_cso <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_openvpn_instance <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_openvpn_statickey <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_plugin <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_route <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_snapshot <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_syslog <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_trust_ca <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_trust_cert <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_trust_crl <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_tunable <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_user <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_zabbix_agent_alias <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
      Opn_zabbix_agent_userparameter <<| tag == $device_name |>> {
        require => Class['opn::config'],
      }
    }
  }
}
