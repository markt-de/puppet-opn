# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_haproxy_backend) do
  desc <<-DOC
    Manages HAProxy backend pools on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "name@device_name". The "name" portion
    (before "@") is the identifier sent to the OPNsense API and must be unique
    per device. It is always set from the title — specifying a different "name"
    value inside the `config` hash has no effect.

    To rename a resource, rename the resource title. If an existing entry must
    be renamed, declare the old title with `ensure => absent` and add a new
    resource with the new title.

    All other configuration validation is delegated to the OPNsense API. The
    `config` hash is passed through to the API without modification.

    @example Define a backend pool
      opn_haproxy_backend { 'web_backend@opnsense.example.com':
        ensure => present,
        config => {
          'mode'        => 'http',
          'description' => 'Web server backend pool',
          'enabled'     => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "backend_name@device_name" format.

      The "backend_name" portion (before "@") is the identifier used in the
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
      A hash of backend configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        mode        - Proxy mode (http or tcp)
        description - Human-readable description
        enabled     - Whether the backend is enabled (1 or 0)

      Refer to OPNsense HAProxy documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    # Exclude 'name': it is always derived from the resource title and
    # overridden in create/flush, so including it would cause an infinite
    # change loop if a different value is specified in config.
    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'name' }.all? do |key, value|
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
