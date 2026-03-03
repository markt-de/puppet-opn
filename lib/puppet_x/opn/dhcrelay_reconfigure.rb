# frozen_string_literal: true

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Opn
    # Shared module used by all opn_dhcrelay* providers to coordinate
    # reconfigure calls. Each provider's post_resource_eval delegates here.
    # The first call performs the work; subsequent calls are no-ops because
    # the hash is cleared after the first run.
    module DhcrelayReconfigure
      @devices_to_reconfigure = {}

      # Registers a device as having pending DHCRelay changes.
      # Subsequent calls for the same device are ignored (client already stored).
      #
      # @param device_name [String]
      # @param client [PuppetX::Opn::ApiClient]
      def self.mark(device_name, client)
        @devices_to_reconfigure[device_name] ||= client
      end

      # Called once after ALL opn_dhcrelay* resources are evaluated.
      # Runs reconfigure for each device with pending changes, then clears
      # the tracking hash so subsequent calls are no-ops.
      def self.run
        @devices_to_reconfigure.each do |device_name, client|
          reconf = client.post('dhcrelay/service/reconfigure', {})
          status = reconf.is_a?(Hash) ? reconf['status'].to_s.strip.downcase : nil
          if status == 'ok'
            Puppet.notice("opn_dhcrelay: reconfigure of '#{device_name}' completed")
          else
            Puppet.warning(
              "opn_dhcrelay: reconfigure of '#{device_name}' returned unexpected " \
              "status: #{reconf.inspect}",
            )
          end
        rescue Puppet::Error => e
          Puppet.err("opn_dhcrelay: reconfigure of '#{device_name}' failed: #{e.message}")
        end
        @devices_to_reconfigure.clear
      end
    end
  end
end
