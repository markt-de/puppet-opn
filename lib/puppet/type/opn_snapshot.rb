# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_snapshot) do
  desc <<-DOC
    Manages ZFS snapshots on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the snapshot and "device_name" corresponds to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    The `active` property controls whether a snapshot is the active boot
    target. Setting `active => true` triggers the activate endpoint. A
    snapshot cannot be deactivated (another snapshot must be activated
    instead). Active snapshots cannot be deleted.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create a snapshot with a note
      opn_snapshot { 'pre-upgrade@opnsense.example.com':
        ensure => present,
        config => {
          'note' => 'Snapshot before upgrade',
        },
      }

    @example Create and activate a snapshot
      opn_snapshot { 'stable@opnsense.example.com':
        ensure => present,
        active => true,
        config => {
          'note' => 'Stable configuration',
        },
      }
  DOC

  # Read-only fields (name, active, dataset, mountpoint, size, created) are
  # excluded from insync? comparison. The 'active' property is managed
  # separately below — it is NOT part of the config hash.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The "name" portion (before "@") is the snapshot identifier.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of snapshot configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        note       - Human-readable note for the snapshot

      Read-only fields (excluded from idempotency checks):
        name       - Set from the resource title
        active     - Managed via the 'active' property
        dataset    - ZFS dataset name (read-only)
        mountpoint - ZFS mountpoint (read-only)
        size       - Snapshot size (read-only)
        created    - Creation timestamp (read-only)

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    skip_fields: ['name', 'active', 'dataset', 'mountpoint', 'size', 'created'])

  # The 'active' property is separate from config and handled by
  # the provider via the activate endpoint. It cannot be deactivated
  # (another snapshot must be activated instead).
  newproperty(:active) do
    desc 'Whether this snapshot is the active boot target.'
    newvalues(:true, :false)
  end
end
