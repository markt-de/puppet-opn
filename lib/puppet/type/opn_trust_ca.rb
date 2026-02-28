# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_trust_ca) do
  desc <<-DOC
    Manages trust Certificate Authorities (CAs) on an OPNsense device via the
    OPNsense REST API.

    The resource title uses the format "descr@device_name", where "descr"
    uniquely identifies the CA and "device_name" corresponds to a YAML config
    file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    Many fields (action, key_type, digest, etc.) are only used during initial
    creation and are ignored during idempotency checks. These volatile fields
    are sent on create but excluded from update operations.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Import an external CA
      opn_trust_ca { 'My Root CA@opnsense.example.com':
        ensure => present,
        config => {
          'action'      => 'import',
          'crt_payload' => '-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----',
        },
      }

    @example Create an internal CA
      opn_trust_ca { 'Internal CA@opnsense.example.com':
        ensure => present,
        config => {
          'action'       => 'internal',
          'key_type'     => 'RSA',
          'digest'       => 'SHA256',
          'lifetime'     => '3650',
          'country'      => 'DE',
          'state'        => 'Berlin',
          'city'         => 'Berlin',
          'organization' => 'Example Corp',
          'commonname'   => 'Internal CA',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "descr@device_name" format.
      The "descr" portion (before "@") is the identifier used in the
      OPNsense API as the CA's description field.
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
      A hash of CA configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Volatile fields (only used during creation, ignored for idempotency):
        action, key_type, digest, lifetime, city, state, organization,
        organizationalunit, country, email, commonname, ocsp_uri,
        crt_payload, prv_payload, refcount, name, valid_from, valid_to

      Refer to OPNsense Trust documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      volatile = ['action', 'key_type', 'digest', 'lifetime', 'city', 'state', 'organization',
                  'organizationalunit', 'country', 'email', 'commonname', 'ocsp_uri',
                  'crt_payload', 'prv_payload', 'refcount', 'name', 'valid_from', 'valid_to']
      should.reject { |k, _| k == 'descr' || volatile.include?(k) }.all? do |key, value|
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
