# frozen_string_literal: true

Puppet::Type.newtype(:opn_hasync) do
  desc <<-DOC
    Manages HA sync (XMLRPC/CARP) settings on an OPNsense device via the
    OPNsense REST API.

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. The `config` hash
    is passed directly to the OPNsense API without modification.

    @example Configure HA sync
      opn_hasync { 'opnsense.example.com':
        ensure => present,
        config => {
          'pfsyncenabled'    => '1',
          'pfsyncinterface'  => 'lan',
          'synchronizetoip'  => '10.0.0.2',
          'username'         => 'root',
          'password'         => 'secret',
        },
      }

    @example Disable HA sync
      opn_hasync { 'opnsense.example.com':
        ensure => absent,
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The OPNsense device name. Must correspond to a config file at
      /etc/puppet/opn/<name>.yaml.
    DOC

    validate do |value|
      unless value.is_a?(String) && !value.empty?
        raise ArgumentError, 'Name must be a non-empty string'
      end
    end
  end

  newproperty(:config) do
    desc <<-DOC
      A hash of HA sync configuration options passed directly to the
      OPNsense API. Validation is performed by the OPNsense API, not Puppet.

      Commonly used keys:
        pfsyncenabled    - Enable pfsync (1 or 0)
        pfsyncinterface  - Interface for pfsync traffic
        pfsyncversion    - pfsync protocol version
        synchronizetoip  - IP of the sync peer
        username         - Sync user
        password         - Sync password (excluded from idempotency check)
        syncitems        - Items to synchronize

      The 'password' field is excluded from idempotency comparison because
      OPNsense does not return it in plaintext.

      Refer to OPNsense HA documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      deep_match?(is, should)
    end

    def deep_match?(is_val, should_val)
      return false unless is_val.is_a?(Hash) && should_val.is_a?(Hash)

      should_val.all? do |k, v|
        next true if k == 'password'

        if v.is_a?(Hash)
          deep_match?(is_val[k], v)
        else
          is_val[k].to_s == v.to_s
        end
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
    ["/etc/puppet/opn/#{self[:name]}.yaml"]
  end
end
