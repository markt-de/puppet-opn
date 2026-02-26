# @summary Manages OPNsense firewalls via the REST API.
#
# This class is the main entry point for the puppet-opn module. It delegates
# provider configuration (config directory, credential files) to opn::config
# and creates opn_* resources for one or more OPNsense devices.
#
# @param cron_jobs
#   Hash of cron jobs to manage across devices.
#   Each key is the cron job description.
#   Each value is a hash with:
#     - devices [Array] List of device names. Defaults to all devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
#     - All other keys are passed as the 'config' hash to opn_cron.
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
# @param plugins
#   Hash of plugins to manage across devices.
#   Each key is the plugin package name (e.g. 'os-haproxy').
#   Each value is a hash with:
#     - devices [Array] List of device names to manage the plugin on.
#                       Defaults to all devices in $devices.
#     - ensure  [String] 'present' or 'absent' (default: 'present')
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
  Hash                 $cron_jobs,
  Hash                 $devices,
  Hash                 $firewall_aliases,
  Hash                 $firewall_categories,
  Hash                 $firewall_groups,
  Hash                 $firewall_rules,
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
  Hash                 $plugins,
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
      require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
      require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
        require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
      require => File["${opn::config::config_dir}/${device_name}.yaml"],
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
      require => File["${opn::config::config_dir}/${device_name}.yaml"],
    }
  }
}
