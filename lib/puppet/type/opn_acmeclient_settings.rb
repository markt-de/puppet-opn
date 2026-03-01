# frozen_string_literal: true

Puppet::Type.newtype(:opn_acmeclient_settings) do
  desc <<-DOC
    Manages ACME Client global settings on an OPNsense device via the
    OPNsense REST API (os-acme-client plugin).

    The resource title is the OPNsense device name, corresponding to a YAML
    config file managed by the opn class at /etc/puppet/opn/<device_name>.yaml.

    This is a singleton resource -- one per OPNsense device. The `config` hash
    is passed directly to the OPNsense API without modification.

    Relation fields (UpdateCron, haproxyAclRef, haproxyActionRef,
    haproxyServerRef, haproxyBackendRef) accept names which are automatically
    resolved to UUIDs.

    After any settings change, Puppet calls `acmeclient/service/reconfigure`
    once per device.

    @example Configure ACME Client settings
      opn_acmeclient_settings { 'opnsense.example.com':
        ensure => present,
        config => {
          'environment' => 'stg',
          'logLevel'    => 'normal',
          'autoRenewal' => '1',
          'UpdateCron'  => 'ACME renew cron',
        },
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
      A hash of ACME Client settings passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not Puppet.

      Relation fields (resolved by name):
        UpdateCron       - Cron job description (single)
        haproxyAclRef    - HAProxy ACL name (single)
        haproxyActionRef - HAProxy action name (single)
        haproxyServerRef - HAProxy server name (single)
        haproxyBackendRef- HAProxy backend name (single)

      Refer to OPNsense ACME Client documentation for all valid keys.
    DOC

    validate do |value|
      raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
    end

    def insync?(is)
      return false unless is.is_a?(Hash)

      should.all? do |key, value|
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
    ["/etc/puppet/opn/#{self[:name]}.yaml"]
  end

  autorequire(:opn_cron) do
    config = self[:config] || {}
    cron = config['UpdateCron'].to_s.strip
    cron.empty? ? [] : ["#{cron}@#{self[:name]}"]
  end

  autorequire(:opn_haproxy_acl) do
    config = self[:config] || {}
    acl = config['haproxyAclRef'].to_s.strip
    acl.empty? ? [] : ["#{acl}@#{self[:name]}"]
  end

  autorequire(:opn_haproxy_action) do
    config = self[:config] || {}
    action = config['haproxyActionRef'].to_s.strip
    action.empty? ? [] : ["#{action}@#{self[:name]}"]
  end

  autorequire(:opn_haproxy_server) do
    config = self[:config] || {}
    server = config['haproxyServerRef'].to_s.strip
    server.empty? ? [] : ["#{server}@#{self[:name]}"]
  end

  autorequire(:opn_haproxy_backend) do
    config = self[:config] || {}
    backend = config['haproxyBackendRef'].to_s.strip
    backend.empty? ? [] : ["#{backend}@#{self[:name]}"]
  end
end
