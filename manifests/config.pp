# @summary Manages provider configuration files for OPNsense API access.
#
# Creates the config directory, per-device credential files, and a provider
# config file that tells the Ruby providers where to find device credentials.
#
# This class can be used standalone to set up provider credentials without
# managing any OPNsense resources via the main opn class.
#
# @param config_dir
#   Directory where per-device YAML credential files are stored.
#
# @param devices
#   Hash of OPNsense devices. Each key is the device name, each value is a
#   hash with connection parameters (url, api_key, api_secret, ssl_verify, timeout).
#
# @param owner
#   Owner of the config directory and credential files.
#
# @param group
#   Group of the config directory and credential files.
#
# @example Standalone usage
#   class { 'opn::config':
#     devices => {
#       'opnsense01' => {
#         'url'        => 'https://opnsense01.example.com/api',
#         'api_key'    => 'key',
#         'api_secret' => 'secret',
#       },
#     },
#   }
#
class opn::config (
  Stdlib::Absolutepath $config_dir,
  Hash                 $devices,
  Optional[String]     $group = undef,
  Optional[String]     $owner = undef,
) {
  # Write a provider config file so the Ruby providers can discover
  # $config_dir. Uses the opn_puppet_confdir fact because
  # ${settings::confdir} returns the server's path, not the agent's.
  file { "${facts['opn_puppet_confdir']}/opn_provider.yaml":
    ensure  => file,
    owner   => $owner,
    group   => $group,
    mode    => '0644',
    content => stdlib::to_yaml({ 'config_dir' => $config_dir }),
  }

  # Ensure the config directory exists with restricted permissions
  file { $config_dir:
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0700',
  }

  # Write one YAML credential file per device via the device_config defined type
  $devices.each |String $device_name, Hash $device_config| {
    opn::device_config { $device_name:
      config_dir    => $config_dir,
      device_config => $device_config,
      group         => $group,
      owner         => $owner,
    }
  }
}
