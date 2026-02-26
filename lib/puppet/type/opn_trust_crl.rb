# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_trust_crl) do
  desc <<-DOC
    Manages Certificate Revocation Lists (CRLs) on an OPNsense device via the
    OPNsense REST API.

    The resource title uses the format "ca_description@device_name", where
    "ca_description" is the description of the CA to which this CRL belongs.
    The provider resolves the CA description to the internal caref identifier.

    Each CA can have at most one CRL. The CRL is identified by its CA
    reference, not by a UUID.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create an internal CRL for a CA
      opn_trust_crl { 'My Root CA@opnsense.example.com':
        ensure => present,
        config => {
          'descr'     => 'CRL for My Root CA',
          'lifetime'  => '9999',
          'crlmethod' => 'internal',
        },
      }

    @example Import an existing CRL
      opn_trust_crl { 'External CA@opnsense.example.com':
        ensure => present,
        config => {
          'descr'     => 'Imported CRL',
          'crlmethod' => 'existing',
          'text'      => '-----BEGIN X509 CRL-----\n...\n-----END X509 CRL-----',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "ca_description@device_name" format.
      The "ca_description" portion identifies the CA this CRL belongs to.
      The provider resolves the CA description to the internal caref.
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
      A hash of CRL configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        descr     - CRL description
        lifetime  - CRL validity in days (default: 9999)
        crlmethod - CRL method: 'internal' or 'existing'
        text      - Base64-encoded CRL content (for crlmethod=existing)

      The 'serial' field and revoked certificate entries are excluded from
      idempotency checks.

      Refer to OPNsense Trust documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    SKIP_FIELDS = %w[serial caref text].freeze

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.each_pair do |key, value|
        next if SKIP_FIELDS.include?(key)
        next if key.start_with?('revoked_reason_')
        return false unless is[key].to_s == value.to_s
      end
      true
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
