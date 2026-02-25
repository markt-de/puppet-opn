# frozen_string_literal: true

module PuppetX
  module Opn
    # Shared module used by all opn_haproxy_* providers to coordinate
    # configtest and reconfigure calls. Each provider's post_resource_eval
    # delegates here. The first call performs the work; subsequent calls
    # are no-ops because the hash is cleared after the first run.
    module HaproxyReconfigure
      @devices_to_reconfigure = {}

      # Registers a device as having pending HAProxy changes.
      # Subsequent calls for the same device are ignored (client already stored).
      #
      # @param device_name [String]
      # @param client [PuppetX::Opn::ApiClient]
      def self.mark(device_name, client)
        @devices_to_reconfigure[device_name] ||= client
      end

      # Called once after ALL opn_haproxy_* resources are evaluated.
      # Runs configtest, then reconfigure for each device with pending changes.
      # Clears the tracking hash so subsequent calls from other provider classes
      # are no-ops.
      def self.run
        @devices_to_reconfigure.each do |device_name, client|
          begin
            result      = client.get('haproxy/service/configtest')
            test_output = result.is_a?(Hash) ? result['result'].to_s : ''

            if test_output.include?('ALERT')
              Puppet.err(
                "opn_haproxy: configtest for '#{device_name}' reported ALERT, " \
                "skipping reconfigure: #{test_output.strip}",
              )
              next
            elsif test_output.include?('WARNING')
              Puppet.warning(
                "opn_haproxy: configtest for '#{device_name}' reported WARNING: " \
                "#{test_output.strip}",
              )
            else
              Puppet.notice("opn_haproxy: configtest for '#{device_name}' passed")
            end

            reconf = client.post('haproxy/service/reconfigure', {})
            status = reconf.is_a?(Hash) ? reconf['status'].to_s.strip.downcase : nil
            if status == 'ok'
              Puppet.notice("opn_haproxy: reconfigure of '#{device_name}' completed")
            else
              Puppet.warning(
                "opn_haproxy: reconfigure of '#{device_name}' returned unexpected " \
                "status: #{reconf.inspect}",
              )
            end
          rescue Puppet::Error => e
            Puppet.err("opn_haproxy: reconfigure of '#{device_name}' failed: #{e.message}")
          end
        end
        @devices_to_reconfigure.clear
      end
    end
  end
end
