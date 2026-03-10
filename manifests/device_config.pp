# @summary Creates a single OPNsense device credential file.
#
# Writes a YAML file containing API credentials for one OPNsense device.
# The file is restricted to mode 0600 and diff output is suppressed to
# protect sensitive data.
#
# @param config_dir
#   Directory where per-device YAML credential files are stored.
#
# @param device_config
#   Hash with connection parameters (url, api_key, api_secret, ssl_verify, timeout).
#
# @param group
#   Group of the credential file.
#
# @param owner
#   Owner of the credential file.
#
# @example
#   opn::device_config { 'opnsense01':
#     config_dir    => '/etc/puppet/opn',
#     device_config => {
#       'url'        => 'https://opnsense01.example.com/api',
#       'api_key'    => 'key',
#       'api_secret' => 'secret',
#     },
#     group         => 'root',
#     owner         => 'root',
#   }
#
define opn::device_config (
  Stdlib::Absolutepath $config_dir,
  Hash                 $device_config,
  String               $group,
  String               $owner,
) {
  file { "${config_dir}/${title}.yaml":
    ensure    => file,
    owner     => $owner,
    group     => $group,
    mode      => '0600',
    content   => stdlib::to_yaml($device_config),
    show_diff => false,
    require   => File[$config_dir],
  }
}
