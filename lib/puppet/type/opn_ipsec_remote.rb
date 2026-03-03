# frozen_string_literal: true

require 'puppet_x/opn/api_client'

Puppet::Type.newtype(:opn_ipsec_remote) do
  desc <<-DOC
    Manages IPsec remote authentication entries on an OPNsense device via the
    OPNsense REST API (Swanctl/MVC model).

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the remote auth entry and "device_name"
    corresponds to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Relation fields (connection, pubkeys) accept names which are automatically
    resolved to UUIDs via the HaproxyUuidResolver.

    @example Create an IPsec remote authentication
      opn_ipsec_remote { 'remote-auth@opnsense.example.com':
        ensure => present,
        config => {
          'connection' => 'site-to-site',
          'auth'       => 'pubkey',
          'id'         => 'CN=remote.example.com',
          'pubkeys'    => 'remote-keypair',
          'enabled'    => '1',
        },
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<-DOC
      The resource title in "description@device_name" format.
      The description must uniquely identify the remote auth entry on the device.
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
      A hash of IPsec remote authentication configuration options passed
      directly to the OPNsense API. Validation is performed by the OPNsense
      API, not Puppet.

      Relation fields (resolved by name):
        connection - IPsec connection description (single)
        pubkeys    - IPsec key pair names (comma-separated)

      Refer to OPNsense IPsec documentation for all valid keys and values.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.reject { |k, _| k == 'description' }.all? do |key, value|
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

  autorequire(:opn_ipsec_connection) do
    device = self[:device]
    config = self[:config] || {}
    connection = config['connection'].to_s.strip
    connection.empty? ? [] : ["#{connection}@#{device}"]
  end

  autorequire(:opn_ipsec_keypair) do
    device = self[:device]
    config = self[:config] || {}
    config['pubkeys'].to_s.split(',').map(&:strip).reject(&:empty?)
                     .map { |s| "#{s}@#{device}" }
  end
end
