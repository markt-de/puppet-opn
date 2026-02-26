# frozen_string_literal: true

# Structured fact exposing OPNsense version and installed plugins.
#
# Only resolves on FreeBSD hosts where the opnsense-version command exists.
#
# Example output:
#   {
#     "name"         => "OPNsense",
#     "architecture" => "amd64",
#     "release"      => {
#       "major" => "26.1",
#       "full"  => "26.1.2",
#       "minor" => "2",
#       "hash"  => "abc123def"
#     },
#     "plugins"      => ["os-haproxy", "os-zabbix-agent"]
#   }
Facter.add(:opnsense) do
  confine kernel: 'FreeBSD'

  setcode do
    opnsense_version = Facter::Core::Execution.which('opnsense-version')
    next unless opnsense_version

    facts = {}

    # opnsense-version -NAVvH outputs:
    #   Name Architecture MajorVersion FullVersion Hash
    # e.g. "OPNsense amd64 26.1 26.1.2 abc123def"
    version_output = Facter::Core::Execution.exec("#{opnsense_version} -NAVvH")
    if version_output
      parts = version_output.strip.split
      if parts.length >= 5
        facts['name'] = parts[0]
        facts['architecture'] = parts[1]
        facts['release'] = {
          'major' => parts[2],
          'full'  => parts[3],
          'minor' => parts[3].split('.')[2].to_s,
          'hash'  => parts[4],
        }
      end
    end

    # pluginctl -g system.firmware.plugins outputs:
    #   os-haproxy,os-zabbix-agent,...
    pluginctl = Facter::Core::Execution.which('pluginctl')
    if pluginctl
      plugin_output = Facter::Core::Execution.exec("#{pluginctl} -g system.firmware.plugins")
      if plugin_output && !plugin_output.strip.empty?
        facts['plugins'] = plugin_output.strip.split(',')
      end
    end

    facts.empty? ? nil : facts
  end
end
