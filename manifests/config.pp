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
#       'fw01' => {
#         'url'        => 'https://fw01.example.com/api',
#         'api_key'    => 'key',
#         'api_secret' => 'secret',
#       },
#     },
#   }
#
class opn::config (
  Stdlib::Absolutepath $config_dir,
  Hash                 $devices,
  String               $owner,
  String               $group,
) {
  # Write a provider config file at the Puppet confdir so the Ruby providers
  # can discover $config_dir without it being hardcoded.
  # ${settings::confdir} in Puppet == Puppet[:confdir] in Ruby, which is
  # automatically correct per OS (e.g. /usr/local/etc/puppet on FreeBSD).
  file { "${settings::confdir}/opn_provider.yaml":
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

  # Write one YAML credential file per device
  $devices.each |String $device_name, Hash $device_config| {
    file { "${config_dir}/${device_name}.yaml":
      ensure    => file,
      owner     => $owner,
      group     => $group,
      mode      => '0600',
      content   => stdlib::to_yaml($device_config),
      show_diff => false,
      require   => File[$config_dir],
    }
  }
}
