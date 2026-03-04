# frozen_string_literal: true

# Returns the Puppet agent confdir setting so manifests can reference
# the correct path regardless of the compiling server's OS.
# $settings::confdir in manifests returns the SERVER's confdir, which
# differs from the agent's on cross-platform setups (e.g. FreeBSD agent
# managed by a Linux Puppet Server).
Facter.add(:opn_puppet_confdir) do
  setcode do
    Puppet[:confdir]
  rescue StandardError
    nil
  end
end
