# frozen_string_literal: true

require 'puppet_x/opn/type_helper'

Puppet::Type.newtype(:opn_cron) do
  desc <<-DOC
    Manages cron jobs on an OPNsense device via the OPNsense REST API.

    The resource title uses the format "description@device_name", where
    "description" uniquely identifies the cron job and "device_name" corresponds
    to a YAML config file managed by the opn class at
    /etc/puppet/opn/<device_name>.yaml.

    Note: The description must be unique per device. Two cron jobs with the same
    description on the same device will cause unpredictable behaviour.

    All configuration validation is delegated to the OPNsense API. The `config`
    hash is passed through to the API without modification.

    @example Create a daily reload cron job
      opn_cron { 'Daily haproxy reload@opnsense.example.com':
        ensure => present,
        config => {
          'command'  => 'haproxy reload',
          'minutes'  => '0',
          'hours'    => '3',
          'days'     => '*',
          'months'   => '*',
          'weekdays' => '*',
          'enabled'  => '1',
        },
      }
  DOC

  # The 'description' field is injected from the resource title by the provider,
  # so it must be excluded from insync? comparisons.
  PuppetX::Opn::TypeHelper.setup(self,
    name_desc: <<-DOC,
      The resource title in "description@device_name" format.
      The description must uniquely identify the cron job on the device.
      The device_name must correspond to a config file at
      /etc/puppet/opn/<device_name>.yaml.
    DOC
    config_desc: <<-DOC,
      A hash of cron job configuration options passed directly to the OPNsense API.
      Validation is performed by the OPNsense API, not by Puppet.

      Commonly used keys:
        command     - The cron command to execute
        minutes     - Minute(s) to run (0-59, * for every minute)
        hours       - Hour(s) to run (0-23, * for every hour)
        days        - Day(s) of month (1-31, * for every day)
        months      - Month(s) (1-12, * for every month)
        weekdays    - Day(s) of week (0-7, * for every day)
        who         - User to run the command as
        enabled     - Whether the job is active (1 or 0)

      Refer to OPNsense documentation for all valid keys and values.
    DOC
    skip_fields: ['description'])
end
