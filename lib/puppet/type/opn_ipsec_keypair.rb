# frozen_string_literal: true

require 'puppet_x/opn/api_client'

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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "name@device_name" format.
      The name must uniquely identify the key pair on the device.
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
      A hash of IPsec key pair configuration options passed directly to
      the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      The 'privateKey' field is excluded from idempotency comparison
      because it contains secret key material.

      Volatile fields (excluded from idempotency checks):
        keyFingerprint, keySize

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      volatile = ['keyFingerprint', 'keySize']
      should.reject { |k, _| k == 'name' || volatile.include?(k) }.all? do |key, value|
        next true if key == 'privateKey'

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
end
