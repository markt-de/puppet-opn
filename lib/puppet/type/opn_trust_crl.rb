# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

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

  # 'serial' and 'caref' are API-managed fields, 'text' is the CRL payload.
  # Fields starting with 'revoked_reason_' are per-certificate revocation
  # reasons that change dynamically and must be excluded from comparison.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "ca_description@device_name" format.
      The "ca_description" portion identifies the CA this CRL belongs to.
      The provider resolves the CA description to the internal caref.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
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
    skip_fields: ['serial', 'caref', 'text'],
    skip_prefixes: ['revoked_reason_'])
end
