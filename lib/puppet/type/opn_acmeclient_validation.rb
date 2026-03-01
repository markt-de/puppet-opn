# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_acmeclient_validation) do
  desc <<-DOC
    Manages ACME Client validation methods on an OPNsense device via the
    OPNsense REST API (os-acme-client plugin).

    The resource title uses the format "name@device_name", where "name"
    uniquely identifies the validation method and "device_name" corresponds
    to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    The relation field http_haproxyFrontends accepts HAProxy frontend names
    which are automatically resolved to UUIDs.

    All configuration validation is delegated to the OPNsense API.

    @example Create an HTTP-01 validation method
      opn_acmeclient_validation { 'http-01@opnsense.example.com':
        ensure => present,
        config => {
          'method'               => 'http01',
          'http_service'         => 'haproxy',
          'http_haproxyFrontends'=> 'https_frontend',
          'enabled'              => '1',
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
      The "name" portion (before "@") is the identifier used in the
      OPNsense API as the validation method's name field.
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
      A hash of ACME validation method configuration options passed directly
      to the OPNsense API. Validation is performed by the OPNsense API, not
      Puppet.

      Relation fields (resolved by name):
        http_haproxyFrontends - HAProxy frontend names (comma-separated)

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

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

  autorequire(:opn_haproxy_frontend) do
    device = self[:device]
    config = self[:config] || {}
    config['http_haproxyFrontends'].to_s.split(',').map(&:strip).reject(&:empty?)
                                   .map { |s| "#{s}@#{device}" }
  end
end
