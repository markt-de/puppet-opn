# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_ipsec_presharedkey) do
  desc <<-DOC
    Manages IPsec pre-shared keys on an OPNsense device via the OPNsense
    REST API (Swanctl/MVC model).

    The resource title uses the format "ident@device_name", where "ident"
    uniquely identifies the pre-shared key and "device_name" corresponds to
    a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The 'Key' field is intentionally excluded from idempotency comparison
    because it contains the actual pre-shared key secret.

    @example Create an IPsec pre-shared key
      opn_ipsec_presharedkey { 'remote-peer@opnsense.example.com':
        ensure => present,
        config => {
          'keyType' => 'PSK',
          'Key'     => 'supersecretkey',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "ident@device_name" format.
      The ident must uniquely identify the pre-shared key on the device.
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
      A hash of IPsec pre-shared key configuration options passed directly
      to the OPNsense API. Validation is performed by the OPNsense API,
      not Puppet.

      The 'Key' field is excluded from idempotency comparison because it
      contains the actual pre-shared key secret.

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'ident' }.all? do |key, value|
        next true if key == 'Key'

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
