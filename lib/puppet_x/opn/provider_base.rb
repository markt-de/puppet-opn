# frozen_string_literal: true

require 'puppet_x/opn/api_client'
require 'puppet_x/opn/service_reconfigure'

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Opn
    # Shared mixin for all opn_* providers, eliminating boilerplate methods.
    #
    # Usage in a provider:
    #   extend  PuppetX::Opn::ProviderBase::ClassMethods
    #   include PuppetX::Opn::ProviderBase::InstanceMethods
    #   reconfigure_group :group_name  # activates error tracking
    #
    # ClassMethods provides:
    #   - reconfigure_group(name) — declares ServiceReconfigure group + error tracking
    #   - reconfigure_group_name — returns the declared group name
    #   - api_client(device_name) — delegates to ApiClient.from_device
    #   - prefetch(resources) — standard Puppet prefetch implementation
    #   - normalize_config(obj) — normalizes OPNsense selection hashes
    #   - selection_hash?(hash) — detects selection hash structures
    #   - normalize_selection(hash) — collapses selected keys to CSV string
    #
    # InstanceMethods provides:
    #   - exists? — checks @property_hash[:ensure] == :present
    #   - config / config= — getter/setter for config property
    #   - api_client (private) — resolves device from property_hash or resource
    #   - resource_item_name (private) — extracts name part before '@'
    #
    # ReconfigureErrorTracking (prepended by reconfigure_group):
    #   - Wraps create/destroy/flush — on exception, calls mark_error
    #     on the ServiceReconfigure group before re-raising
    module ProviderBase
      # Class-level methods added via `extend`.
      module ClassMethods
        # Declares the ServiceReconfigure group for this provider and activates
        # automatic error tracking via ReconfigureErrorTracking prepend.
        # When create/destroy/flush raises, mark_error is called on the group
        # before the exception is re-raised.
        #
        # @param name [Symbol] The ServiceReconfigure group name (e.g. :haproxy)
        def reconfigure_group(name)
          @reconfigure_group_name = name
          prepend PuppetX::Opn::ProviderBase::ReconfigureErrorTracking
        end

        # Returns the declared ServiceReconfigure group name, or nil.
        #
        # @return [Symbol, nil]
        def reconfigure_group_name
          @reconfigure_group_name
        end

        # Returns an ApiClient instance for the given device.
        #
        # @param device_name [String]
        # @return [PuppetX::Opn::ApiClient]
        def api_client(device_name)
          PuppetX::Opn::ApiClient.from_device(device_name)
        end

        # Standard Puppet prefetch: matches provider instances to declared
        # resources by name.
        #
        # @param resources [Hash{String => Puppet::Resource}]
        def prefetch(resources)
          all_instances = instances
          resources.each do |name, resource|
            provider = all_instances.find { |inst| inst.name == name }
            resource.provider = provider if provider
          end
        end

        # Recursively normalizes OPNsense selection hashes to simple values.
        #
        # OPNsense returns multi-select fields as hashes like:
        #   { "opt1" => { "value" => "...", "selected" => 1 },
        #     "opt2" => { "value" => "...", "selected" => 0 } }
        #
        # This method collapses them to comma-separated strings of selected
        # keys (e.g. "opt1") and recurses into nested hashes.
        #
        # @param obj [Object] The value to normalize
        # @return [Object] Normalized value
        def normalize_config(obj)
          return obj unless obj.is_a?(Hash)
          return normalize_selection(obj) if selection_hash?(obj)

          obj.transform_values { |v| normalize_config(v) }
        end

        # Detects whether a hash is an OPNsense selection hash.
        #
        # A selection hash has non-empty entries where every value is a Hash
        # containing at least 'value' and 'selected' keys.
        #
        # @param hash [Hash]
        # @return [Boolean]
        def selection_hash?(hash)
          hash.is_a?(Hash) &&
            !hash.empty? &&
            hash.values.all? { |v| v.is_a?(Hash) && v.key?('value') && v.key?('selected') }
        end

        # Collapses a selection hash to a comma-separated string of selected keys.
        #
        # @param hash [Hash] A selection hash (as detected by selection_hash?)
        # @return [String] Comma-separated selected keys
        def normalize_selection(hash)
          hash.select { |_k, v| v['selected'].to_i == 1 }.keys.join(',')
        end
      end

      # Automatic error tracking for ServiceReconfigure groups.
      # Prepended by reconfigure_group() to wrap create/destroy/flush — on
      # exception, marks the device as errored so reconfigure is skipped.
      module ReconfigureErrorTracking
        # @see Puppet::Provider#create
        def create(*args)
          super
        rescue StandardError
          mark_reconfigure_error
          raise
        end

        # @see Puppet::Provider#destroy
        def destroy(*args)
          super
        rescue StandardError
          mark_reconfigure_error
          raise
        end

        # @see Puppet::Provider#flush
        def flush(*args)
          super
        rescue StandardError
          mark_reconfigure_error
          raise
        end

        private

        # Resolves the device name and marks it as errored in ServiceReconfigure.
        # Singleton types have no :device param — resource[:name] is the device.
        def mark_reconfigure_error
          group = self.class.reconfigure_group_name
          return unless group

          device = @property_hash[:device] || resource[:device] || resource[:name]
          PuppetX::Opn::ServiceReconfigure[group].mark_error(device)
        end
      end

      # Instance-level methods added via `include`.
      module InstanceMethods
        # Returns true if the provider instance represents an existing resource.
        #
        # @return [Boolean]
        def exists?
          @property_hash[:ensure] == :present
        end

        # Returns the current config hash from the property hash.
        #
        # @return [Hash, nil]
        def config
          @property_hash[:config]
        end

        # Stores the desired config for later application in flush.
        #
        # @param value [Hash]
        def config=(value)
          @pending_config = value
        end

        private

        # Returns an ApiClient for the current resource's device.
        # Prefers device from property_hash (prefetched), falls back to
        # resource parameter (new resource being created).
        #
        # @return [PuppetX::Opn::ApiClient]
        def api_client
          device = @property_hash[:device] || resource[:device]
          self.class.api_client(device)
        end

        # Extracts the name part before '@' from the resource title.
        # For resources without '@', returns the full name.
        #
        # @return [String]
        def resource_item_name
          resource[:name].split('@', 2).first
        end
      end
    end
  end
end
