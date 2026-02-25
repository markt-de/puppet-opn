# puppet-opn

#### Table of Contents

1. [Overview](#overview)
1. [Requirements](#requirements)
1. [Usage](#usage)
    - [Basic usage](#basic-usage)
    - [Multiple devices](#multiple-devices)
    - [Resource identifiers](#resource-identifiers)
    - [Managing plugins](#managing-plugins)
    - [Managing firewall aliases](#managing-firewall-aliases)
    - [Managing firewall categories](#managing-firewall-categories)
    - [Managing firewall interface groups](#managing-firewall-interface-groups)
    - [Managing firewall rules](#managing-firewall-rules)
    - [Managing users](#managing-users)
    - [Managing groups](#managing-groups)
    - [Managing HAProxy](#managing-haproxy)
    - [Managing Zabbix Proxy](#managing-zabbix-proxy)
    - [Managing Zabbix Agent](#managing-zabbix-agent)
    - [Using types directly](#using-types-directly)
1. [Reference](#reference)
1. [Development](#development)
    - [Contributing](#contributing)
1. [License](#license)

## Overview

A Puppet module to manage [OPNsense](https://opnsense.org/) firewalls via the OPNsense REST API. It is meant as a replacement for [puppet-opnsense](https://github.com/andreas-stuerz/puppet-opnsense).


This module provides the following resource types for one or more OPNsense devices:

| Type | Manages |
|------|---------|
| `opn_firewall_alias` | Firewall aliases |
| `opn_firewall_category` | Firewall categories |
| `opn_firewall_group` | Firewall interface groups |
| `opn_firewall_rule` | Firewall filter rules (new GUI) |
| `opn_group` | Local groups |
| `opn_haproxy_acl` | HAProxy ACL rules |
| `opn_haproxy_action` | HAProxy actions |
| `opn_haproxy_backend` | HAProxy backend pools |
| `opn_haproxy_cpu` | HAProxy CPU affinity / thread binding |
| `opn_haproxy_errorfile` | HAProxy error files |
| `opn_haproxy_fcgi` | HAProxy FastCGI applications |
| `opn_haproxy_frontend` | HAProxy frontend listeners |
| `opn_haproxy_group` | HAProxy user-list groups |
| `opn_haproxy_healthcheck` | HAProxy health checks |
| `opn_haproxy_lua` | HAProxy Lua scripts |
| `opn_haproxy_mailer` | HAProxy mailers |
| `opn_haproxy_mapfile` | HAProxy map files |
| `opn_haproxy_resolver` | HAProxy DNS resolvers |
| `opn_haproxy_server` | HAProxy backend servers |
| `opn_haproxy_user` | HAProxy user-list users |
| `opn_plugin` | Firmware plugins / packages |
| `opn_user` | Local users |
| `opn_zabbix_agent` | Zabbix Agent settings (singleton per device) |
| `opn_zabbix_agent_alias` | Zabbix Agent Alias entries |
| `opn_zabbix_agent_userparameter` | Zabbix Agent UserParameter entries |
| `opn_zabbix_proxy` | Zabbix Proxy settings (singleton per device) |

## Requirements

One or more OPNsense firewalls with API access enabled. API credentials can be created in OPNsense under **System → Access → Users → (User) → API keys**.

No external tools are required. Communication with the OPNsense API is done natively using Ruby's built-in HTTP library.

## Usage

### Basic usage

The `opn` class manages API credential files for one or more OPNsense devices. These files are written to `$config_dir` and are read by the `opn_*` providers at catalog application time.

```puppet
class { 'opn':
  devices => {
    'localhost' => {
      'url'        => 'https://localhost/api',
      'api_key'    => 'OPNSENSE_API_KEY',
      'api_secret' => 'OPNSENSE_API_SECRET',
      'ssl_verify' => false,
    },
  },
  plugins => {
    'os-helloworld' => {
      'devices' => ['localhost'],
      'ensure'  => 'present',
    },
  },
  firewall_aliases => {
    'alias_test001' => {
      'devices'     => ['localhost'],
      'ensure'      => 'present',
      'type'        => 'host',
      'content'     => '192.168.1.1',
      'description' => 'Test alias',
      'enabled'     => '1',
    },
  },
}
```

Note that for some parameters, OPNsense expects a newline as separator. In these cases the value must be provided as `"value1\nvalue2"`, as demonstrated in some examples below. One of the main goals of this module is code simplification, so this is not done by the provider.

### Multiple devices

When managing more than one OPNsense firewall, add each device to the `devices` hash. Resource titles use the `resource_name@device_name` format to identify which device a resource belongs to.

```puppet
class { 'opn':
  devices => {
    'opnsense01.example.com' => {
      'url'        => 'https://opnsense01.example.com/api',
      'api_key'    => 'OPNSENSE_API_KEY',
      'api_secret' => 'OPNSENSE_API_SECRET',
      'ssl_verify' => true,
    },
    'opnsense02.example.com' => {
      'url'        => 'https://opnsense02.example.com/api',
      'api_key'    => 'OPNSENSE_API_KEY',
      'api_secret' => 'OPNSENSE_API_SECRET',
      'ssl_verify' => true,
    },
  },
}
```

### Resource identifiers

Most `opn_*` resource types manage **lists of entries** (firewall aliases, HAProxy servers, Zabbix UserParameters, etc.). Their resource title uses the format `identifier@device_name`, where the part before `@` is the **unique identifier** that OPNsense uses to track the entry — for example the alias name, the server description, or the Zabbix UserParameter key.

This identifier is set from the resource title, not from the `config` hash. Specifying the identifier field inside `config` has no effect — the title value always takes precedence and is what gets written to OPNsense.

As a consequence, **renaming an identifier requires two steps**: declare the old resource with `ensure => absent` and add a new resource with the new identifier in the title.

```puppet
# Step 1: remove the old entry
opn_haproxy_server { 'web01@opnsense01.example.com':
  ensure => absent,
}
# Step 2: add the new entry with the renamed identifier
opn_haproxy_server { 'web-primary@opnsense01.example.com':
  ensure => present,
  config => {
    'address' => '10.0.0.1',
    'port'    => '80',
    'enabled' => '1',
  },
}
```

The same pattern applies to all list-based types: `opn_firewall_alias`, `opn_firewall_category`, `opn_firewall_group`, `opn_firewall_rule`, `opn_user`, `opn_group`, all `opn_haproxy_*` types, `opn_zabbix_agent_userparameter`, and `opn_zabbix_agent_alias`.

**Singleton resources** (`opn_zabbix_proxy`, `opn_zabbix_agent`) are different: their title is the device name itself, and the entire `config` hash is written to the OPNsense API on every change.

### Managing plugins

Plugins can be managed via the `plugins` parameter of the `opn` class or directly using the `opn_plugin` type. The `devices` key controls which firewalls the plugin is deployed to. If `devices` is omitted, the plugin is applied to all devices defined in `$devices`.

```puppet
class { 'opn':
  devices => { ... },
  plugins => {
    'os-haproxy' => {
      'devices' => ['opnsense01.example.com'],
      'ensure'  => 'present',
    },
    'os-acme-client' => {
      'devices' => ['opnsense01.example.com', 'opnsense02.example.com'],
      'ensure'  => 'present',
    },
  },
}
```

### Managing firewall aliases

Firewall aliases can be managed via the `firewall_aliases` parameter or directly via the `opn_firewall_alias` type. The alias configuration is passed directly to the OPNsense API without modification. All validation is performed by OPNsense.

Common alias types include `host`, `network`, `port`, `url`, `urltable`, `geoip` and `networkgroup`.

```puppet
class { 'opn':
  devices => { ... },
  firewall_aliases => {
    'mgmt_hosts' => {
      'devices'     => ['opnsense01.example.com'],
      'ensure'      => 'present',
      'type'        => 'host',
      'content'     => "10.0.0.1\n10.0.0.2",
      'description' => 'Management hosts',
      'enabled'     => '1',
    },
    'http_ports' => {
      'devices'     => ['opnsense01.example.com', 'opnsense02.example.com'],
      'ensure'      => 'present',
      'type'        => 'port',
      'content'     => "80\n443",
      'description' => 'HTTP(S) ports',
      'enabled'     => '1',
    },
  },
}
```

### Managing firewall categories

Firewall categories are used to organise rules and aliases. The category name is the resource identifier and must be unique per device.

```puppet
class { 'opn':
  devices => { ... },
  firewall_categories => {
    'web' => {
      'devices' => ['opnsense01.example.com'],
      'ensure'  => 'present',
      'color'   => '0088cc',
    },
  },
}
```

### Managing firewall interface groups

Interface groups are logical collections of interfaces usable in firewall rules. The interface group name (`ifname`) is the resource identifier. System-provided groups (e.g. `enc0`, `openvpn`, `wireguard`) are read-only and are automatically excluded from Puppet management.

```puppet
class { 'opn':
  devices => { ... },
  firewall_groups => {
    'dmz_ifaces' => {
      'devices' => ['opnsense01.example.com'],
      'ensure'  => 'present',
      'members' => 'em1,em2',
      'descr'   => 'DMZ interfaces',
    },
  },
}
```

### Managing firewall rules

Firewall filter rules are managed via the new OPNsense filter GUI API. The rule **description** is used as the resource identifier and must be unique per device. Changes are applied once per Puppet run via `firewall/filter/apply`.

```puppet
class { 'opn':
  devices => { ... },
  firewall_rules => {
    'Allow HTTPS from LAN' => {
      'devices'          => ['opnsense01.example.com'],
      'ensure'           => 'present',
      'action'           => 'pass',
      'interface'        => 'lan',
      'ipprotocol'       => 'inet',
      'protocol'         => 'tcp',
      'source_net'       => 'any',
      'destination_net'  => 'any',
      'destination_port' => '443',
      'enabled'          => '1',
    },
  },
}
```

### Managing users

Local OPNsense users can be managed via the `users` parameter or directly via the `opn_user` type.

```puppet
class { 'opn':
  devices => { ... },
  users => {
    'jdoe' => {
      'devices'     => ['opnsense01.example.com'],
      'ensure'      => 'present',
      'password'    => 'plaintextpassword',
      'descr'       => 'John Doe',
      'email'       => 'jdoe@example.com',
      # The 'uid' attribute is optional. Be aware that OPNsense will
      # change the uid if it is already taken by another user.
      #'uid'        => '2001',
    },
  },
}
```

### Managing groups

Local OPNsense groups can be managed via the `groups` parameter or directly via the `opn_group` type.

```puppet
class { 'opn':
  devices => { ... },
  groups => {
    'vpn_users' => {
      'devices'     => ['opnsense01.example.com'],
      'ensure'      => 'present',
      'description' => 'VPN Users',
      # The 'member' attribute expects UID values.
      #'member'     => '2000,2001,2002',
    },
  },
}
```

### Managing HAProxy

HAProxy resources are managed via the `haproxy_*` parameters of the `opn` class or directly via the corresponding `opn_haproxy_*` types.

After any HAProxy change (create, update, or delete), Puppet runs `haproxy/service/configtest` once per device. If the config test reports an **ALERT**, the reconfigure step is skipped and Puppet logs an error. A **WARNING** is logged but reconfigure proceeds. The actual `haproxy/service/reconfigure` call is made at most once per device per Puppet run, regardless of how many HAProxy resources changed.

```puppet
class { 'opn':
  devices => {
    'opnsense01.example.com' => {
      'url'        => 'https://opnsense01.example.com/api',
      'api_key'    => 'OPNSENSE_API_KEY',
      'api_secret' => 'OPNSENSE_API_SECRET',
    },
  },
  haproxy_servers => {
    'web01' => {
      'devices'     => ['opnsense01.example.com'],
      'ensure'      => 'present',
      'address'     => '10.0.0.1',
      'port'        => '80',
      'description' => 'Web server 01',
      'enabled'     => '1',
    },
  },
  haproxy_backends => {
    'web_pool' => {
      'devices'     => ['opnsense01.example.com'],
      'ensure'      => 'present',
      'mode'        => 'http',
      'description' => 'Web backend pool',
      'enabled'     => '1',
    },
  },
  haproxy_frontends => {
    'http_in' => {
      'devices'          => ['opnsense01.example.com'],
      'ensure'           => 'present',
      'bind'             => '0.0.0.0:80',
      'mode'             => 'http',
      'description'      => 'HTTP listener',
      'enabled'          => '1',
    },
  },
}
```

### Managing Zabbix Proxy

The Zabbix Proxy configuration is a singleton resource — one per OPNsense device. It requires the `os-zabbix-proxy` plugin to be installed. Use `opn_plugin` to install it before applying the settings.

The `zabbix_proxies` hash is keyed by **device name** (not by a `name@device` title), since only one Zabbix Proxy configuration exists per device. All keys other than `ensure` are passed as the `config` hash to `opn_zabbix_proxy`.

After any change, Puppet calls `zabbixproxy/service/reconfigure` once to apply the new configuration.

```puppet
class { 'opn':
  devices => {
    'opnsense01.example.com' => {
      'url'        => 'https://opnsense01.example.com/api',
      'api_key'    => 'OPNSENSE_API_KEY',
      'api_secret' => 'OPNSENSE_API_SECRET',
    },
  },
  plugins => {
    'os-zabbix-proxy' => {
      'devices' => ['opnsense01.example.com'],
      'ensure'  => 'present',
    },
  },
  zabbix_proxies => {
    'opnsense01.example.com' => {
      'ensure'     => 'present',
      'enabled'    => '1',
      'server'     => 'zabbix.example.com',
      'serverport' => '10051',
      'hostname'   => 'opnsense01-proxy',
    },
  },
}
```

### Managing Zabbix Agent

The Zabbix Agent configuration is also a singleton resource per device. It requires the `os-zabbix-agent` plugin.

The `zabbix_agents` hash is keyed by **device name**. All keys other than `ensure` are passed as the `config` hash to `opn_zabbix_agent`. The config structure mirrors the nested OPNsense ZabbixAgent model (`settings.main`, `settings.tuning`, `settings.features`, `local`).

UserParameter and Alias entries are managed separately via `zabbix_agent_userparameters` and `zabbix_agent_aliases`. All changes to agent resources trigger a single `zabbixagent/service/reconfigure` call per device per Puppet run.

The hash key in `zabbix_agent_userparameters` and `zabbix_agent_aliases` is the **Zabbix key** (the identifier sent to OPNsense). It must not be repeated inside the config — any `key` value there is ignored. See [Resource identifiers](#resource-identifiers) for the general explanation and rename pattern.

```puppet
class { 'opn':
  devices => {
    'opnsense01.example.com' => {
      'url'        => 'https://opnsense01.example.com/api',
      'api_key'    => 'OPNSENSE_API_KEY',
      'api_secret' => 'OPNSENSE_API_SECRET',
    },
  },
  plugins => {
    'os-zabbix-agent' => {
      'devices' => ['opnsense01.example.com'],
      'ensure'  => 'present',
    },
  },
  zabbix_agents => {
    'opnsense01.example.com' => {
      'ensure' => 'present',
      'local' => {
        'hostname' => 'opnsense01.example.com',
      },
      'settings' => {
        'main' => {
          'enabled'    => '1',
          'serverList' => 'zabbix.example.com',
          'listenPort' => '10050',
        },
        'features' => {
          'enableActiveChecks'   => '1',
          'activeCheckServers'   => 'zabbix.example.com',
          'enableRemoteCommands' => '0',
        },
      },
    },
  },
  zabbix_agent_userparameters => {
    'custom.uptime' => {
      'devices'      => ['opnsense01.example.com'],
      'ensure'       => 'present',
      'command'      => '/usr/bin/uptime',
      'enabled'      => '1',
      'acceptParams' => '0',
    },
  },
  zabbix_agent_aliases => {
    'ping' => {
      'devices'      => ['opnsense01.example.com'],
      'ensure'       => 'present',
      'sourceKey'    => 'icmpping',
      'enabled'      => '1',
      'acceptParams' => '0',
    },
  },
}
```

### Using types directly

All types can also be used directly without the `opn` wrapper class, provided the credential file already exists at `$config_dir/<device_name>.yaml`.

```puppet
opn_plugin { 'os-haproxy@opnsense01.example.com':
  ensure => present,
}

opn_firewall_alias { 'http_ports@opnsense01.example.com':
  ensure => present,
  config => {
    'type'        => 'port',
    'content'     => "80\n443",
    'description' => 'HTTP(S) ports',
    'enabled'     => '1',
  },
}

opn_firewall_category { 'web@opnsense01.example.com':
  ensure => present,
  config => { 'color' => '0088cc' },
}

opn_firewall_group { 'dmz_ifaces@opnsense01.example.com':
  ensure => present,
  config => {
    'members' => 'em1,em2',
    'descr'   => 'DMZ interfaces',
  },
}

opn_firewall_rule { 'Allow SSH from mgmt@opnsense01.example.com':
  ensure => present,
  config => {
    'action'          => 'pass',
    'interface'       => 'lan',
    'protocol'        => 'tcp',
    'source_net'      => 'mgmt_hosts',
    'destination_port'=> '22',
    'enabled'         => '1',
  },
}

opn_user { 'jdoe@opnsense01.example.com':
  ensure => present,
  config => {
    'password'    => '$2y$11$...',
    'description' => 'John Doe',
  },
}

opn_group { 'vpn_users@opnsense01.example.com':
  ensure => present,
  config => { 'description' => 'VPN Users' },
}

opn_haproxy_server { 'web01@opnsense01.example.com':
  ensure => present,
  config => {
    'address'     => '10.0.0.1',
    'port'        => '80',
    'description' => 'Web server 01',
    'enabled'     => '1',
  },
}

opn_haproxy_backend { 'web_pool@opnsense01.example.com':
  ensure => present,
  config => {
    'mode'        => 'http',
    'description' => 'Web backend pool',
    'enabled'     => '1',
  },
}

opn_haproxy_frontend { 'http_in@opnsense01.example.com':
  ensure => present,
  config => {
    'bind'        => '0.0.0.0:80',
    'mode'        => 'http',
    'description' => 'HTTP listener',
    'enabled'     => '1',
  },
}

opn_zabbix_proxy { 'opnsense01.example.com':
  ensure => present,
  config => {
    'enabled'    => '1',
    'server'     => 'zabbix.example.com',
    'serverport' => '10051',
    'hostname'   => 'opnsense01-proxy',
  },
}

opn_zabbix_agent { 'opnsense01.example.com':
  ensure => present,
  config => {
    'local' => {
      'hostname' => 'opnsense01.example.com',
    },
    'settings' => {
      'main' => {
        'enabled'    => '1',
        'serverList' => 'zabbix.example.com',
        'listenPort' => '10050',
      },
    },
  },
}

opn_zabbix_agent_userparameter { 'custom.uptime@opnsense01.example.com':
  ensure => present,
  config => {
    'command'      => '/usr/bin/uptime',
    'enabled'      => '1',
    'acceptParams' => '0',
  },
}

opn_zabbix_agent_alias { 'ping@opnsense01.example.com':
  ensure => present,
  config => {
    'sourceKey'    => 'icmpping',
    'enabled'      => '1',
    'acceptParams' => '0',
  },
}
```

## Reference

Classes and parameters are documented in [REFERENCE.md](REFERENCE.md).

All default values can be found in the `data/` directory.

## Development

### Contributing

Please use the GitHub issues functionality to report any bugs or requests for new features. Feel free to fork and submit pull requests for potential contributions.

## License

BSD-2-Clause
