# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_user) do
  desc <<-DOC
    Manages local users on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "username@device_name", where
    "device_name" corresponds to a YAML config file managed by the opn class
    at /etc/puppet/opn/<device_name>.yaml.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create a local user
      opn_user { 'jdoe@opnsense.example.com':
        ensure => present,
        config => {
          'password'    => '$2y$11$...',
          'description' => 'John Doe',
          'email'       => 'jdoe@example.com',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "username@device_name" format.
      The username must be a valid OPNsense local user name.
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
        descr       - Full name or description
        email       - Email address
        shell       - Login shell
        expires     - Account expiry date (YYYY-MM-DD)
        disabled    - Whether the account is disabled (0 or 1)

      Refer to OPNsense documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    # Partial comparison: only keys specified in the desired state are compared.
    # The 'password' field is intentionally excluded from comparison because
    # OPNsense expects a plaintext password and hashes it with bcrypt internally.
    # The stored bcrypt hash can never be equal to the plaintext supplied in the
    # manifest, so idempotent comparison is structurally impossible. The password
    # is written on resource creation but cannot be verified on subsequent runs.
    def insync?(is)
      return false unless is.is_a?(Hash)

      should.all? do |key, value|
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
