# frozen_string_literal: true

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Opn
    # Unified reconfigure handler with registry pattern.
    #
    # Each reconfigure group is registered as a named instance. Providers
    # call mark() during create/destroy/flush and run() from
    # post_resource_eval. The first run() call performs the work; subsequent
    # calls are no-ops because the tracking hash is cleared.
    #
    # Error tracking is built in: if any provider marks a device as errored
    # (via mark_error), reconfigure is skipped for that device.
    # HAProxy additionally uses configtest before reconfiguring.
    #
    # @example Register a simple reconfigure group
    #   PuppetX::Opn::ServiceReconfigure.register(:ipsec,
    #     endpoint: 'ipsec/service/reconfigure',
    #     log_prefix: 'opn_ipsec')
    #
    # @example Register a group with configtest (HAProxy pattern)
    #   PuppetX::Opn::ServiceReconfigure.register(:haproxy,
    #     endpoint: 'haproxy/service/reconfigure',
    #     log_prefix: 'opn_haproxy',
    #     configtest_endpoint: 'haproxy/service/configtest')
    #
    # @example Usage in a provider
    #   PuppetX::Opn::ServiceReconfigure[:ipsec].mark(device, client)
    #   PuppetX::Opn::ServiceReconfigure[:ipsec].run
    class ServiceReconfigure
      # Global registry of named instances.
      @registry = {}

      # Registers a new reconfigure group. Idempotent — returns the existing
      # instance if the name is already registered.
      #
      # @param name [Symbol] Unique group identifier (e.g. :haproxy, :ipsec)
      # @param endpoint [String] API endpoint for POST reconfigure call
      # @param log_prefix [String] Prefix for Puppet log messages
      # @param configtest_endpoint [String, nil] Optional GET endpoint for
      #   configtest (HAProxy pattern). When set, configtest is run before
      #   reconfigure and ALERT results skip reconfigure.
      # @return [ServiceReconfigure] The registered instance
      def self.register(name, endpoint:, log_prefix:, configtest_endpoint: nil)
        @registry[name] ||= new(
          endpoint: endpoint,
          log_prefix: log_prefix,
          configtest_endpoint: configtest_endpoint,
        )
      end

      # Retrieves a registered instance by name.
      #
      # @param name [Symbol]
      # @return [ServiceReconfigure]
      # @raise [Puppet::Error] if the name is not registered
      def self.[](name)
        instance = @registry[name]
        raise Puppet::Error, "ServiceReconfigure: unknown group '#{name}'" unless instance

        instance
      end

      # Returns all registered group names.
      #
      # @return [Array<Symbol>]
      def self.registered_names
        @registry.keys
      end

      # Clears all registrations and instance state. Used in tests to ensure
      # clean state between examples.
      def self.reset!
        @registry.each_value(&:clear_state)
        @registry.clear
      end

      # Registers a device as having pending changes. Subsequent calls for
      # the same device are ignored (first client wins).
      #
      # @param device_name [String]
      # @param client [PuppetX::Opn::ApiClient]
      def mark(device_name, client)
        @devices_to_reconfigure[device_name] ||= client
      end

      # Registers a device as having a resource evaluation error. Used to
      # suppress reconfigure when the service config may be inconsistent.
      #
      # @param device_name [String]
      def mark_error(device_name)
        @devices_with_errors[device_name] = true
      end

      # Performs reconfigure for all marked devices, then clears state.
      # Subsequent calls are no-ops until new devices are marked.
      #
      # For all groups: skips devices with resource evaluation errors.
      # For groups with configtest_endpoint: additionally runs configtest,
      # skips reconfigure on ALERT, logs and proceeds on WARNING.
      def run
        @devices_to_reconfigure.each do |device_name, client|
          reconfigure_device(device_name, client)
        end
        clear_state
      end

      # Clears all tracking state (devices + errors). Called by run() and
      # exposed for reset! in tests.
      def clear_state
        @devices_to_reconfigure.clear
        @devices_with_errors.clear
      end

      private

      # @param endpoint [String]
      # @param log_prefix [String]
      # @param configtest_endpoint [String, nil]
      def initialize(endpoint:, log_prefix:, configtest_endpoint:)
        @endpoint = endpoint
        @log_prefix = log_prefix
        @configtest_endpoint = configtest_endpoint
        @devices_to_reconfigure = {}
        @devices_with_errors = {}
      end

      # Reconfigures a single device, handling configtest and error tracking
      # if configured.
      #
      # @param device_name [String]
      # @param client [PuppetX::Opn::ApiClient]
      def reconfigure_device(device_name, client)
        # Skip devices with resource evaluation errors
        if @devices_with_errors[device_name]
          Puppet.err(
            "#{@log_prefix}: skipping reconfigure for '#{device_name}' " \
            'because one or more resources failed to evaluate',
          )
          return
        end

        # Run configtest if configured (HAProxy pattern).
        # Skip reconfigure if configtest fails (returns false on ALERT).
        if @configtest_endpoint
          return unless run_configtest(device_name, client)
        end

        # Execute reconfigure
        execute_reconfigure(device_name, client)
      rescue Puppet::Error => e
        Puppet.err("#{@log_prefix}: reconfigure of '#{device_name}' failed: #{e.message}")
      end

      # Runs configtest for a device. Returns true if reconfigure should
      # proceed, false if it should be skipped (ALERT).
      #
      # @param device_name [String]
      # @param client [PuppetX::Opn::ApiClient]
      # @return [Boolean] true if reconfigure should proceed
      def run_configtest(device_name, client)
        result      = client.get(@configtest_endpoint)
        test_output = result.is_a?(Hash) ? result['result'].to_s : ''

        if test_output.include?('ALERT')
          Puppet.err(
            "#{@log_prefix}: configtest for '#{device_name}' reported ALERT, " \
            "skipping reconfigure: #{test_output.strip}",
          )
          return false
        elsif test_output.include?('WARNING')
          Puppet.warning(
            "#{@log_prefix}: configtest for '#{device_name}' reported WARNING: " \
            "#{test_output.strip}",
          )
        else
          Puppet.notice("#{@log_prefix}: configtest for '#{device_name}' passed")
        end

        true
      end

      # Executes the reconfigure POST and logs the result.
      #
      # @param device_name [String]
      # @param client [PuppetX::Opn::ApiClient]
      def execute_reconfigure(device_name, client)
        reconf = client.post(@endpoint, {})
        status = reconf.is_a?(Hash) ? reconf['status'].to_s.strip.downcase : nil
        if status == 'ok'
          Puppet.notice("#{@log_prefix}: reconfigure of '#{device_name}' completed")
        else
          Puppet.warning(
            "#{@log_prefix}: reconfigure of '#{device_name}' returned unexpected " \
            "status: #{reconf.inspect}",
          )
        end
      end
    end
  end
end
