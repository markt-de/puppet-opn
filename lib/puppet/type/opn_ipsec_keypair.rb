# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_ipsec_keypair) do
  desc <<-DOC
    Manages IPsec key pairs on an OPNsense device via the OPNsense REST API
    (Swanctl/MVC model).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the key pair and "device_name" corresponds to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    The 'privateKey' field is intentionally excluded from idempotency
    comparison because it contains secret key material.

    Volatile fields (keyFingerprint, keySize) are computed by OPNsense and
    excluded from idempotency checks.

    @example Create an IPsec key pair
      opn_ipsec_keypair { 'my-keypair@opnsense.example.com':
        ensure => present,
        config => {
          'keyType'    => 'rsa',
          'keySize'    => '2048',
          'privateKey' => '-----BEGIN RSA PRIVATE KEY-----...',
          'publicKey'  => '-----BEGIN PUBLIC KEY-----...',
        },
      }
  DOC

  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "name@device_name" format.
      The name must uniquely identify the key pair on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of IPsec key pair configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      The 'privateKey' field is excluded from idempotency comparison
      because it contains secret key material.

      Volatile fields (excluded from idempotency checks):
        keyFingerprint, keySize

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC
    skip_fields: ['name'],
    volatile_fields: ['keyFingerprint', 'keySize'],
    password_fields: ['privateKey'])
end
