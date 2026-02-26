# frozen_string_literal: true

require 'puppet_x/opn/api_client'

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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "name@device_name" format.
      The "name" portion (before "@") is the snapshot identifier.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC

    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, 'Name must be a non-empty string'
      end
    end
  end

  newparam(:device) do
    desc <<-DOC
      The OPNsense device name. If not explicitly set, it is extracted
      from the resource title (the part after the last "@" character).
      Falls back to "default" if no "@" is present in the title.
    DOC

    defaultto do
      title = @resource[:name]
      title.include?('@') ? title.split('@', 2).last : 'default'
    end
  end

  newproperty(:active) do
    desc 'Whether this snapshot is the active boot target.'
    newvalues(:true, :false)
  end

  newproperty(:config) do
    desc <<-DOC
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

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    READONLY_FIELDS = %w[name active dataset mountpoint size created].freeze

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| READONLY_FIELDS.include?(k) }.all? do |key, value|
        is[key].to_s == value.to_s
      end
    end

    def is_to_s(current_value)
      current_value.inspect
    end

    def should_to_s(new_value)
      new_value.inspect
    end
  end

  autorequire(:file) do
    device = self[:device]
    ["/etc/puppet/opn/#{device}.yaml"]
  end
end
