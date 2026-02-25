# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_haproxy_user) do
  desc <<-DOC
    Manages HAProxy user-list users on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name". The "name" portion
    (before "@") is the identifier sent to the OPNsense API and must be unique
    per device. It is always set from the title — specifying a different "name"
    value inside the `config` hash has no effect.

    To rename a resource, rename the resource title. If an existing entry must
    be renamed, declare the old title with `ensure => absent` and add a new
    resource with the new title.

    All other configuration validation is delegated to the OPNsense API. The
    `config` hash is passed through to the API without modification.

    @example Define a HAProxy user
      opn_haproxy_user { 'stats_user@opnsense.example.com':
        ensure => present,
        config => {
          'password'    => 'secretpassword',
          'description' => 'Stats page user',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "user_name@device_name" format.

      The "user_name" portion (before "@") is the identifier used in the
      OPNsense API as the resource's "name" field. This value is set from
      the title — it is NOT taken from the `config` hash. Any "name" value
      in `config` is ignored.

      To rename a resource, declare the old title with `ensure => absent`
      and create a new resource with the desired name in the title.

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

  newproperty(:config) do
    desc <<-DOC
      A hash of user configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        password    - Plaintext password (OPNsense hashes it internally with bcrypt)
        description - Human-readable description

      The 'password' field is intentionally excluded from idempotency comparison
      because OPNsense hashes it with bcrypt internally. The stored hash can never
      equal the plaintext supplied in the manifest.

      Refer to OPNsense HAProxy documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    # Partial comparison: only keys specified in the desired state are compared.
    # 'name' is excluded: it is always derived from the resource title and
    # overridden in create/flush — specifying a different value in config has
    # no effect and would cause an infinite change loop.
    # 'password' is excluded: OPNsense hashes it with bcrypt internally, so
    # the stored hash can never equal the plaintext supplied in the manifest.
    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'name' }.all? do |key, value|
        next true if key == 'password'

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
