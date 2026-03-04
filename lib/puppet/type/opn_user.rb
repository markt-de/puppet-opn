# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

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

  # The 'password' field is excluded from idempotency comparison because
  # OPNsense expects a plaintext password and hashes it with bcrypt internally.
  # The stored bcrypt hash can never equal the plaintext supplied in the
  # manifest, so idempotent comparison is structurally impossible.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "username@device_name" format.
      The username must be a valid OPNsense local user name.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
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
    password_fields: ['password'])
end
