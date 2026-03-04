# frozen_string_literal: true

require 'puppet_x/opn/service_reconfigure'

# Central registration of all reconfigure groups used by opn_* providers.
#
# Each registration maps a symbolic name to an API endpoint and log prefix.
# Providers reference these groups via ServiceReconfigure[:name].mark/run
# instead of maintaining their own inline reconfigure logic.
#
# HAProxy is the only group that uses a configtest endpoint — all others
# perform a direct reconfigure without validation.

# --- Shared reconfigure modules (previously separate files) ---

# HAProxy: configtest before reconfigure, error tracking for failed resources
PuppetX::Opn::ServiceReconfigure.register(:haproxy,
  endpoint: 'haproxy/service/reconfigure',
  log_prefix: 'opn_haproxy',
  configtest_endpoint: 'haproxy/service/configtest')

# IPsec: simple reconfigure after connection/child/keypair/etc. changes
PuppetX::Opn::ServiceReconfigure.register(:ipsec,
  endpoint: 'ipsec/service/reconfigure',
  log_prefix: 'opn_ipsec')

# OpenVPN: simple reconfigure after instance/cso/statickey changes
PuppetX::Opn::ServiceReconfigure.register(:openvpn,
  endpoint: 'openvpn/service/reconfigure',
  log_prefix: 'opn_openvpn')

# Zabbix Agent: reconfigure after agent settings/userparameter/alias changes
PuppetX::Opn::ServiceReconfigure.register(:zabbix_agent,
  endpoint: 'zabbixagent/service/reconfigure',
  log_prefix: 'opn_zabbix_agent')

# DHCRelay: reconfigure after relay/destination changes
PuppetX::Opn::ServiceReconfigure.register(:dhcrelay,
  endpoint: 'dhcrelay/service/reconfigure',
  log_prefix: 'opn_dhcrelay')

# --- Inline reconfigure groups (previously @devices_to_reconfigure in providers) ---

# Cron: reconfigure after cron job changes
PuppetX::Opn::ServiceReconfigure.register(:cron,
  endpoint: 'cron/service/reconfigure',
  log_prefix: 'opn_cron')

# Firewall aliases: alias-specific reconfigure endpoint
PuppetX::Opn::ServiceReconfigure.register(:firewall_alias,
  endpoint: 'firewall/alias/reconfigure',
  log_prefix: 'opn_firewall_alias')

# Firewall rules: uses 'apply' instead of 'reconfigure'
PuppetX::Opn::ServiceReconfigure.register(:firewall_rule,
  endpoint: 'firewall/filter/apply',
  log_prefix: 'opn_firewall_rule')

# Firewall groups: group-specific reconfigure endpoint
PuppetX::Opn::ServiceReconfigure.register(:firewall_group,
  endpoint: 'firewall/group/reconfigure',
  log_prefix: 'opn_firewall_group')

# HA sync: core hasync reconfigure
PuppetX::Opn::ServiceReconfigure.register(:hasync,
  endpoint: 'core/hasync/reconfigure',
  log_prefix: 'opn_hasync')

# Syslog: reconfigure after destination changes
PuppetX::Opn::ServiceReconfigure.register(:syslog,
  endpoint: 'syslog/service/reconfigure',
  log_prefix: 'opn_syslog')

# Tunables: reconfigure after sysctl tunable changes
PuppetX::Opn::ServiceReconfigure.register(:tunable,
  endpoint: 'core/tunables/reconfigure',
  log_prefix: 'opn_tunable')

# ACME Client: reconfigure after settings changes
PuppetX::Opn::ServiceReconfigure.register(:acmeclient,
  endpoint: 'acmeclient/service/reconfigure',
  log_prefix: 'opn_acmeclient')

# Node Exporter: reconfigure after settings changes
PuppetX::Opn::ServiceReconfigure.register(:node_exporter,
  endpoint: 'nodeexporter/service/reconfigure',
  log_prefix: 'opn_node_exporter')

# Gateway: routing reconfigure after gateway changes
PuppetX::Opn::ServiceReconfigure.register(:gateway,
  endpoint: 'routing/settings/reconfigure',
  log_prefix: 'opn_gateway')

# Routes: route-specific reconfigure after static route changes
PuppetX::Opn::ServiceReconfigure.register(:route,
  endpoint: 'routes/routes/reconfigure',
  log_prefix: 'opn_route')
