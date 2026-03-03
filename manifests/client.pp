# @summary Exports OPNsense resources for collection by the management server.
#
# This class is used on client nodes (e.g. application servers) to declare
# exported opn_* resources. The management server running the opn class with
# manage_resources => true collects and applies these resources via PuppetDB.
#
# Each resource item must include a 'devices' key listing the target OPNsense
# device names. Unlike the opn class, there is no global devices list to
# fall back to.
#
# Singleton types (opn_acmeclient_settings, opn_haproxy_settings, opn_hasync,
# opn_zabbix_agent, opn_zabbix_proxy) are excluded because they represent
# per-device global settings that should only be managed by the opn class on
# the management server.
#
# @param acmeclient_accounts
#   Hash of ACME Client accounts to export.
#   Each key is the account name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_account.
#
# @param acmeclient_actions
#   Hash of ACME Client automation actions to export.
#   Each key is the action name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_action.
#
# @param acmeclient_certificates
#   Hash of ACME Client certificates to export.
#   Each key is the certificate name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_certificate.
#
# @param acmeclient_validations
#   Hash of ACME Client validation methods to export.
#   Each key is the validation method name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_acmeclient_validation.
#
# @param cron_jobs
#   Hash of cron jobs to export.
#   Each key is the cron job description.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_cron.
#
# @param dhcrelay_destinations
#   Hash of DHCP Relay destinations to export.
#   Each key is the destination name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_dhcrelay_destination.
#
# @param dhcrelays
#   Hash of DHCP Relay instances to export.
#   Each key is a freeform label (not sent to the API).
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_dhcrelay.
#
# @param firewall_aliases
#   Hash of firewall aliases to export.
#   Each key is the alias name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_alias.
#
# @param firewall_categories
#   Hash of firewall categories to export.
#   Each key is the category name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_category.
#
# @param firewall_groups
#   Hash of firewall interface groups to export.
#   Each key is the interface group name (ifname).
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_group.
#
# @param firewall_rules
#   Hash of firewall filter rules to export.
#   Each key is the rule description.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_firewall_rule.
#
# @param groups
#   Hash of local groups to export.
#   Each key is the group name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_group.
#
# @param haproxy_acls
#   Hash of HAProxy ACL rules to export.
#   Each key is the ACL name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_acl.
#
# @param haproxy_actions
#   Hash of HAProxy actions to export.
#   Each key is the action name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_action.
#
# @param haproxy_backends
#   Hash of HAProxy backends to export.
#   Each key is the backend name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_backend.
#
# @param haproxy_cpus
#   Hash of HAProxy CPU affinity entries to export.
#   Each key is the CPU entry name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_cpu.
#
# @param haproxy_errorfiles
#   Hash of HAProxy error files to export.
#   Each key is the error file name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_errorfile.
#
# @param haproxy_fcgis
#   Hash of HAProxy FastCGI applications to export.
#   Each key is the FastCGI application name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_fcgi.
#
# @param haproxy_frontends
#   Hash of HAProxy frontends to export.
#   Each key is the frontend name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_frontend.
#
# @param haproxy_groups
#   Hash of HAProxy user-list groups to export.
#   Each key is the group name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_group.
#
# @param haproxy_healthchecks
#   Hash of HAProxy health checks to export.
#   Each key is the health check name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_healthcheck.
#
# @param haproxy_luas
#   Hash of HAProxy Lua scripts to export.
#   Each key is the Lua script name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_lua.
#
# @param haproxy_mailers
#   Hash of HAProxy mailers to export.
#   Each key is the mailer name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_mailer.
#
# @param haproxy_mapfiles
#   Hash of HAProxy map files to export.
#   Each key is the map file name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_mapfile.
#
# @param haproxy_resolvers
#   Hash of HAProxy DNS resolvers to export.
#   Each key is the resolver name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_resolver.
#
# @param haproxy_servers
#   Hash of HAProxy backend servers to export.
#   Each key is the server name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_server.
#
# @param haproxy_users
#   Hash of HAProxy user-list users to export.
#   Each key is the user name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_haproxy_user.
#
# @param plugins
#   Hash of plugins to export.
#   Each key is the plugin package name (e.g. 'os-haproxy').
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#
# @param snapshots
#   Hash of ZFS snapshots to export.
#   Each key is the snapshot name.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - active  [Boolean] Whether snapshot is the active boot target.
#     - All other keys are passed as the 'config' hash to opn_snapshot.
#
# @param syslog_destinations
#   Hash of syslog destinations to export.
#   Each key is the syslog destination description.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_syslog.
#
# @param trust_cas
#   Hash of trust CAs to export.
#   Each key is the CA description.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_trust_ca.
#
# @param trust_certs
#   Hash of trust certificates to export.
#   Each key is the certificate description.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_trust_cert.
#
# @param trust_crls
#   Hash of trust CRLs to export.
#   Each key is the CA description the CRL belongs to.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_trust_crl.
#
# @param tunables
#   Hash of system tunables to export.
#   Each key is the sysctl variable name (e.g. 'kern.maxproc').
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_tunable.
#
# @param users
#   Hash of local users to export.
#   Each key is the username.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_user.
#
# @param zabbix_agent_aliases
#   Hash of Zabbix Agent Alias entries to export.
#   Each key is the alias key.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_zabbix_agent_alias.
#
# @param zabbix_agent_userparameters
#   Hash of Zabbix Agent UserParameter entries to export.
#   Each key is the userparameter key.
#   Each value is a hash with:
#     - devices [Array] List of target device names (mandatory).
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_zabbix_agent_userparameter.
#
# @example Export a firewall alias from a client node
#   class { 'opn::client':
#     firewall_aliases => {
#       'webserver_ips' => {
#         'devices'     => ['opnsense01.example.com'],
#         'type'        => 'host',
#         'content'     => $facts['networking']['ip'],
#         'description' => "${facts['networking']['fqdn']} - Web server IPs",
#         'enabled'     => '1',
#       },
#     },
#   }
#
class opn::client (
  Hash $acmeclient_accounts,
  Hash $acmeclient_actions,
  Hash $acmeclient_certificates,
  Hash $acmeclient_validations,
  Hash $cron_jobs,
  Hash $dhcrelay_destinations,
  Hash $dhcrelays,
  Hash $firewall_aliases,
  Hash $firewall_categories,
  Hash $firewall_groups,
  Hash $firewall_rules,
  Hash $groups,
  Hash $haproxy_acls,
  Hash $haproxy_actions,
  Hash $haproxy_backends,
  Hash $haproxy_cpus,
  Hash $haproxy_errorfiles,
  Hash $haproxy_fcgis,
  Hash $haproxy_frontends,
  Hash $haproxy_groups,
  Hash $haproxy_healthchecks,
  Hash $haproxy_luas,
  Hash $haproxy_mailers,
  Hash $haproxy_mapfiles,
  Hash $haproxy_resolvers,
  Hash $haproxy_servers,
  Hash $haproxy_users,
  Hash $plugins,
  Hash $snapshots,
  Hash $syslog_destinations,
  Hash $trust_cas,
  Hash $trust_certs,
  Hash $trust_crls,
  Hash $tunables,
  Hash $users,
  Hash $zabbix_agent_aliases,
  Hash $zabbix_agent_userparameters,
) {
  # Export ACME Client accounts
  $acmeclient_accounts.each |String $item_name, Hash $item_options| {
    $acme_account_devices = $item_options['devices']
    $acme_account_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_account_config = $item_options - ['devices', 'ensure']

    $acme_account_devices.each |String $device_name| {
      @@opn_acmeclient_account { "${item_name}@${device_name}":
        ensure => $acme_account_ensure,
        config => $acme_account_config,
        tag    => $device_name,
      }
    }
  }

  # Export ACME Client automation actions
  $acmeclient_actions.each |String $item_name, Hash $item_options| {
    $acme_action_devices = $item_options['devices']
    $acme_action_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_action_config = $item_options - ['devices', 'ensure']

    $acme_action_devices.each |String $device_name| {
      @@opn_acmeclient_action { "${item_name}@${device_name}":
        ensure => $acme_action_ensure,
        config => $acme_action_config,
        tag    => $device_name,
      }
    }
  }

  # Export ACME Client certificates
  $acmeclient_certificates.each |String $item_name, Hash $item_options| {
    $acme_cert_devices = $item_options['devices']
    $acme_cert_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_cert_config = $item_options - ['devices', 'ensure']

    $acme_cert_devices.each |String $device_name| {
      @@opn_acmeclient_certificate { "${item_name}@${device_name}":
        ensure => $acme_cert_ensure,
        config => $acme_cert_config,
        tag    => $device_name,
      }
    }
  }

  # Export ACME Client validation methods
  $acmeclient_validations.each |String $item_name, Hash $item_options| {
    $acme_validation_devices = $item_options['devices']
    $acme_validation_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $acme_validation_config = $item_options - ['devices', 'ensure']

    $acme_validation_devices.each |String $device_name| {
      @@opn_acmeclient_validation { "${item_name}@${device_name}":
        ensure => $acme_validation_ensure,
        config => $acme_validation_config,
        tag    => $device_name,
      }
    }
  }

  # Export cron jobs
  $cron_jobs.each |String $job_desc, Hash $job_options| {
    $job_devices = $job_options['devices']
    $job_ensure = 'ensure' in $job_options ? {
      true    => $job_options['ensure'],
      default => 'present',
    }
    $job_config = $job_options - ['devices', 'ensure']

    $job_devices.each |String $device_name| {
      @@opn_cron { "${job_desc}@${device_name}":
        ensure => $job_ensure,
        config => $job_config,
        tag    => $device_name,
      }
    }
  }

  # Export DHCP Relay destinations
  $dhcrelay_destinations.each |String $item_name, Hash $item_options| {
    $dhcrelay_dest_devices = $item_options['devices']
    $dhcrelay_dest_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $dhcrelay_dest_config = $item_options - ['devices', 'ensure']

    $dhcrelay_dest_devices.each |String $device_name| {
      @@opn_dhcrelay_destination { "${item_name}@${device_name}":
        ensure => $dhcrelay_dest_ensure,
        config => $dhcrelay_dest_config,
        tag    => $device_name,
      }
    }
  }

  # Export DHCP Relay instances
  $dhcrelays.each |String $item_name, Hash $item_options| {
    $dhcrelay_devices = $item_options['devices']
    $dhcrelay_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $dhcrelay_config = $item_options - ['devices', 'ensure']

    $dhcrelay_devices.each |String $device_name| {
      @@opn_dhcrelay { "${item_name}@${device_name}":
        ensure => $dhcrelay_ensure,
        config => $dhcrelay_config,
        tag    => $device_name,
      }
    }
  }

  # Export firewall aliases
  $firewall_aliases.each |String $alias_name, Hash $alias_options| {
    $alias_devices = $alias_options['devices']
    $alias_ensure = 'ensure' in $alias_options ? {
      true    => $alias_options['ensure'],
      default => 'present',
    }
    $alias_config = $alias_options - ['devices', 'ensure']

    $alias_devices.each |String $device_name| {
      @@opn_firewall_alias { "${alias_name}@${device_name}":
        ensure => $alias_ensure,
        config => $alias_config,
        tag    => $device_name,
      }
    }
  }

  # Export firewall categories
  $firewall_categories.each |String $cat_name, Hash $cat_options| {
    $cat_devices = $cat_options['devices']
    $cat_ensure = 'ensure' in $cat_options ? {
      true    => $cat_options['ensure'],
      default => 'present',
    }
    $cat_config = $cat_options - ['devices', 'ensure']

    $cat_devices.each |String $device_name| {
      @@opn_firewall_category { "${cat_name}@${device_name}":
        ensure => $cat_ensure,
        config => $cat_config,
        tag    => $device_name,
      }
    }
  }

  # Export firewall interface groups
  $firewall_groups.each |String $fwgroup_name, Hash $fwgroup_options| {
    $fwgroup_devices = $fwgroup_options['devices']
    $fwgroup_ensure = 'ensure' in $fwgroup_options ? {
      true    => $fwgroup_options['ensure'],
      default => 'present',
    }
    $fwgroup_config = $fwgroup_options - ['devices', 'ensure']

    $fwgroup_devices.each |String $device_name| {
      @@opn_firewall_group { "${fwgroup_name}@${device_name}":
        ensure => $fwgroup_ensure,
        config => $fwgroup_config,
        tag    => $device_name,
      }
    }
  }

  # Export firewall filter rules
  $firewall_rules.each |String $rule_desc, Hash $rule_options| {
    $rule_devices = $rule_options['devices']
    $rule_ensure = 'ensure' in $rule_options ? {
      true    => $rule_options['ensure'],
      default => 'present',
    }
    $rule_config = $rule_options - ['devices', 'ensure']

    $rule_devices.each |String $device_name| {
      @@opn_firewall_rule { "${rule_desc}@${device_name}":
        ensure => $rule_ensure,
        config => $rule_config,
        tag    => $device_name,
      }
    }
  }

  # Export local groups
  $groups.each |String $group_name, Hash $group_options| {
    $group_devices = $group_options['devices']
    $group_ensure = 'ensure' in $group_options ? {
      true    => $group_options['ensure'],
      default => 'present',
    }
    $group_config = $group_options - ['devices', 'ensure']

    $group_devices.each |String $device_name| {
      @@opn_group { "${group_name}@${device_name}":
        ensure => $group_ensure,
        config => $group_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy ACLs
  $haproxy_acls.each |String $item_name, Hash $item_options| {
    $haproxy_acl_devices = $item_options['devices']
    $haproxy_acl_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_acl_config = $item_options - ['devices', 'ensure']

    $haproxy_acl_devices.each |String $device_name| {
      @@opn_haproxy_acl { "${item_name}@${device_name}":
        ensure => $haproxy_acl_ensure,
        config => $haproxy_acl_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy actions
  $haproxy_actions.each |String $item_name, Hash $item_options| {
    $haproxy_action_devices = $item_options['devices']
    $haproxy_action_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_action_config = $item_options - ['devices', 'ensure']

    $haproxy_action_devices.each |String $device_name| {
      @@opn_haproxy_action { "${item_name}@${device_name}":
        ensure => $haproxy_action_ensure,
        config => $haproxy_action_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy backends
  $haproxy_backends.each |String $item_name, Hash $item_options| {
    $haproxy_backend_devices = $item_options['devices']
    $haproxy_backend_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_backend_config = $item_options - ['devices', 'ensure']

    $haproxy_backend_devices.each |String $device_name| {
      @@opn_haproxy_backend { "${item_name}@${device_name}":
        ensure => $haproxy_backend_ensure,
        config => $haproxy_backend_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy CPU affinity entries
  $haproxy_cpus.each |String $item_name, Hash $item_options| {
    $haproxy_cpu_devices = $item_options['devices']
    $haproxy_cpu_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_cpu_config = $item_options - ['devices', 'ensure']

    $haproxy_cpu_devices.each |String $device_name| {
      @@opn_haproxy_cpu { "${item_name}@${device_name}":
        ensure => $haproxy_cpu_ensure,
        config => $haproxy_cpu_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy error files
  $haproxy_errorfiles.each |String $item_name, Hash $item_options| {
    $haproxy_errorfile_devices = $item_options['devices']
    $haproxy_errorfile_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_errorfile_config = $item_options - ['devices', 'ensure']

    $haproxy_errorfile_devices.each |String $device_name| {
      @@opn_haproxy_errorfile { "${item_name}@${device_name}":
        ensure => $haproxy_errorfile_ensure,
        config => $haproxy_errorfile_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy FastCGI applications
  $haproxy_fcgis.each |String $item_name, Hash $item_options| {
    $haproxy_fcgi_devices = $item_options['devices']
    $haproxy_fcgi_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_fcgi_config = $item_options - ['devices', 'ensure']

    $haproxy_fcgi_devices.each |String $device_name| {
      @@opn_haproxy_fcgi { "${item_name}@${device_name}":
        ensure => $haproxy_fcgi_ensure,
        config => $haproxy_fcgi_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy frontends
  $haproxy_frontends.each |String $item_name, Hash $item_options| {
    $haproxy_frontend_devices = $item_options['devices']
    $haproxy_frontend_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_frontend_config = $item_options - ['devices', 'ensure']

    $haproxy_frontend_devices.each |String $device_name| {
      @@opn_haproxy_frontend { "${item_name}@${device_name}":
        ensure => $haproxy_frontend_ensure,
        config => $haproxy_frontend_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy user-list groups
  $haproxy_groups.each |String $item_name, Hash $item_options| {
    $haproxy_group_devices = $item_options['devices']
    $haproxy_group_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_group_config = $item_options - ['devices', 'ensure']

    $haproxy_group_devices.each |String $device_name| {
      @@opn_haproxy_group { "${item_name}@${device_name}":
        ensure => $haproxy_group_ensure,
        config => $haproxy_group_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy health checks
  $haproxy_healthchecks.each |String $item_name, Hash $item_options| {
    $haproxy_healthcheck_devices = $item_options['devices']
    $haproxy_healthcheck_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_healthcheck_config = $item_options - ['devices', 'ensure']

    $haproxy_healthcheck_devices.each |String $device_name| {
      @@opn_haproxy_healthcheck { "${item_name}@${device_name}":
        ensure => $haproxy_healthcheck_ensure,
        config => $haproxy_healthcheck_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy Lua scripts
  $haproxy_luas.each |String $item_name, Hash $item_options| {
    $haproxy_lua_devices = $item_options['devices']
    $haproxy_lua_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_lua_config = $item_options - ['devices', 'ensure']

    $haproxy_lua_devices.each |String $device_name| {
      @@opn_haproxy_lua { "${item_name}@${device_name}":
        ensure => $haproxy_lua_ensure,
        config => $haproxy_lua_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy mailers
  $haproxy_mailers.each |String $item_name, Hash $item_options| {
    $haproxy_mailer_devices = $item_options['devices']
    $haproxy_mailer_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_mailer_config = $item_options - ['devices', 'ensure']

    $haproxy_mailer_devices.each |String $device_name| {
      @@opn_haproxy_mailer { "${item_name}@${device_name}":
        ensure => $haproxy_mailer_ensure,
        config => $haproxy_mailer_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy map files
  $haproxy_mapfiles.each |String $item_name, Hash $item_options| {
    $haproxy_mapfile_devices = $item_options['devices']
    $haproxy_mapfile_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_mapfile_config = $item_options - ['devices', 'ensure']

    $haproxy_mapfile_devices.each |String $device_name| {
      @@opn_haproxy_mapfile { "${item_name}@${device_name}":
        ensure => $haproxy_mapfile_ensure,
        config => $haproxy_mapfile_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy DNS resolvers
  $haproxy_resolvers.each |String $item_name, Hash $item_options| {
    $haproxy_resolver_devices = $item_options['devices']
    $haproxy_resolver_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_resolver_config = $item_options - ['devices', 'ensure']

    $haproxy_resolver_devices.each |String $device_name| {
      @@opn_haproxy_resolver { "${item_name}@${device_name}":
        ensure => $haproxy_resolver_ensure,
        config => $haproxy_resolver_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy servers
  $haproxy_servers.each |String $item_name, Hash $item_options| {
    $haproxy_server_devices = $item_options['devices']
    $haproxy_server_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_server_config = $item_options - ['devices', 'ensure']

    $haproxy_server_devices.each |String $device_name| {
      @@opn_haproxy_server { "${item_name}@${device_name}":
        ensure => $haproxy_server_ensure,
        config => $haproxy_server_config,
        tag    => $device_name,
      }
    }
  }

  # Export HAProxy user-list users
  $haproxy_users.each |String $item_name, Hash $item_options| {
    $haproxy_user_devices = $item_options['devices']
    $haproxy_user_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $haproxy_user_config = $item_options - ['devices', 'ensure']

    $haproxy_user_devices.each |String $device_name| {
      @@opn_haproxy_user { "${item_name}@${device_name}":
        ensure => $haproxy_user_ensure,
        config => $haproxy_user_config,
        tag    => $device_name,
      }
    }
  }

  # Export plugins (no config property)
  $plugins.each |String $plugin_name, Hash $plugin_options| {
    $plugin_devices = $plugin_options['devices']
    $plugin_ensure = 'ensure' in $plugin_options ? {
      true    => $plugin_options['ensure'],
      default => 'present',
    }

    $plugin_devices.each |String $device_name| {
      @@opn_plugin { "${plugin_name}@${device_name}":
        ensure => $plugin_ensure,
        tag    => $device_name,
      }
    }
  }

  # Export ZFS snapshots (extra active property)
  $snapshots.each |String $snap_name, Hash $snap_options| {
    $snap_devices = $snap_options['devices']
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
      @@opn_snapshot { "${snap_name}@${device_name}":
        ensure => $snap_ensure,
        active => $snap_active,
        config => $snap_config,
        tag    => $device_name,
      }
    }
  }

  # Export syslog destinations
  $syslog_destinations.each |String $dest_desc, Hash $dest_options| {
    $dest_devices = $dest_options['devices']
    $dest_ensure = 'ensure' in $dest_options ? {
      true    => $dest_options['ensure'],
      default => 'present',
    }
    $dest_config = $dest_options - ['devices', 'ensure']

    $dest_devices.each |String $device_name| {
      @@opn_syslog { "${dest_desc}@${device_name}":
        ensure => $dest_ensure,
        config => $dest_config,
        tag    => $device_name,
      }
    }
  }

  # Export trust CAs
  $trust_cas.each |String $ca_descr, Hash $ca_options| {
    $ca_devices = $ca_options['devices']
    $ca_ensure = 'ensure' in $ca_options ? {
      true    => $ca_options['ensure'],
      default => 'present',
    }
    $ca_config = $ca_options - ['devices', 'ensure']

    $ca_devices.each |String $device_name| {
      @@opn_trust_ca { "${ca_descr}@${device_name}":
        ensure => $ca_ensure,
        config => $ca_config,
        tag    => $device_name,
      }
    }
  }

  # Export trust certificates
  $trust_certs.each |String $cert_descr, Hash $cert_options| {
    $cert_devices = $cert_options['devices']
    $cert_ensure = 'ensure' in $cert_options ? {
      true    => $cert_options['ensure'],
      default => 'present',
    }
    $cert_config = $cert_options - ['devices', 'ensure']

    $cert_devices.each |String $device_name| {
      @@opn_trust_cert { "${cert_descr}@${device_name}":
        ensure => $cert_ensure,
        config => $cert_config,
        tag    => $device_name,
      }
    }
  }

  # Export trust CRLs
  $trust_crls.each |String $crl_ca_descr, Hash $crl_options| {
    $crl_devices = $crl_options['devices']
    $crl_ensure = 'ensure' in $crl_options ? {
      true    => $crl_options['ensure'],
      default => 'present',
    }
    $crl_config = $crl_options - ['devices', 'ensure']

    $crl_devices.each |String $device_name| {
      @@opn_trust_crl { "${crl_ca_descr}@${device_name}":
        ensure => $crl_ensure,
        config => $crl_config,
        tag    => $device_name,
      }
    }
  }

  # Export system tunables
  $tunables.each |String $tunable_key, Hash $tunable_options| {
    $tunable_devices = $tunable_options['devices']
    $tunable_ensure = 'ensure' in $tunable_options ? {
      true    => $tunable_options['ensure'],
      default => 'present',
    }
    $tunable_config = $tunable_options - ['devices', 'ensure']

    $tunable_devices.each |String $device_name| {
      @@opn_tunable { "${tunable_key}@${device_name}":
        ensure => $tunable_ensure,
        config => $tunable_config,
        tag    => $device_name,
      }
    }
  }

  # Export local users
  $users.each |String $user_name, Hash $user_options| {
    $user_devices = $user_options['devices']
    $user_ensure = 'ensure' in $user_options ? {
      true    => $user_options['ensure'],
      default => 'present',
    }
    $user_config = $user_options - ['devices', 'ensure']

    $user_devices.each |String $device_name| {
      @@opn_user { "${user_name}@${device_name}":
        ensure => $user_ensure,
        config => $user_config,
        tag    => $device_name,
      }
    }
  }

  # Export Zabbix Agent aliases
  $zabbix_agent_aliases.each |String $item_name, Hash $item_options| {
    $zabbix_alias_devices = $item_options['devices']
    $zabbix_alias_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $zabbix_alias_config = $item_options - ['devices', 'ensure']

    $zabbix_alias_devices.each |String $device_name| {
      @@opn_zabbix_agent_alias { "${item_name}@${device_name}":
        ensure => $zabbix_alias_ensure,
        config => $zabbix_alias_config,
        tag    => $device_name,
      }
    }
  }

  # Export Zabbix Agent userparameters
  $zabbix_agent_userparameters.each |String $item_name, Hash $item_options| {
    $zabbix_up_devices = $item_options['devices']
    $zabbix_up_ensure = 'ensure' in $item_options ? {
      true    => $item_options['ensure'],
      default => 'present',
    }
    $zabbix_up_config = $item_options - ['devices', 'ensure']

    $zabbix_up_devices.each |String $device_name| {
      @@opn_zabbix_agent_userparameter { "${item_name}@${device_name}":
        ensure => $zabbix_up_ensure,
        config => $zabbix_up_config,
        tag    => $device_name,
      }
    }
  }
}
