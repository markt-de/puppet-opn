# frozen_string_literal: true

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Opn
    # Shared helper for opn_* type definitions, eliminating boilerplate code
    # that was previously duplicated across 57 type files.
    #
    # Generates ensurable, name param (with validation), device param
    # (with extraction from title), and config property (with insync?,
    # validation, is_to_s/should_to_s) in a single call.
    #
    # @example Standard list type
    #   PuppetX::Opn::TypeHelper.setup(self,
    #     name_desc: 'Resource title in "name@device_name" format.',
    #     config_desc: 'A hash of configuration options.',
    #     skip_fields: ['name'])
    #
    # @example Singleton type with deep_match
    #   PuppetX::Opn::TypeHelper.setup(self,
    #     name_desc: 'OPNsense device name.',
    #     config_desc: 'A hash of settings.',
    #     singleton: true,
    #     insync_mode: :deep_match)
    #
    # @example Type without config property
    #   PuppetX::Opn::TypeHelper.setup(self,
    #     name_desc: 'Plugin name@device_name.')
    module TypeHelper
      # Generates standard type elements (ensurable, params, properties).
      #
      # @param type_class [Puppet::Type] The type class (pass `self` from newtype block)
      # @param name_desc [String] Description for the :name parameter
      # @param config_desc [String, nil] Description for the :config property (nil = no config)
      # @param singleton [Boolean] If true, no :device parameter is generated
      # @param insync_mode [Symbol] Comparison mode — :simple, :deep_match, or :casecmp
      # @param skip_fields [Array<String>] Fields excluded from insync? comparison
      # @param volatile_fields [Array<String>] API-generated fields excluded from insync?
      # @param password_fields [Array<String>] Fields always treated as in-sync (passwords/secrets)
      # @param skip_prefixes [Array<String>] Prefix-based field skip (e.g. 'revoked_reason_')
      # @param autorequires [Hash] Declarative autorequires:
      #   { type_symbol => { field: 'config_key', multiple: false } }
      #   When multiple: true, the field value is split on ',' to produce
      #   multiple autorequire entries.
      def self.setup(type_class,
                     name_desc:,
                     config_desc: nil,
                     singleton: false,
                     insync_mode: :simple,
                     skip_fields: [],
                     volatile_fields: [],
                     password_fields: [],
                     skip_prefixes: [],
                     autorequires: {})
        setup_ensurable(type_class)
        setup_name_param(type_class, name_desc)
        setup_device_param(type_class) unless singleton
        if config_desc
          setup_config_property(type_class, config_desc,
                                insync_mode: insync_mode,
                                skip_fields: skip_fields,
                                volatile_fields: volatile_fields,
                                password_fields: password_fields,
                                skip_prefixes: skip_prefixes)
        end
        setup_autorequires(type_class, autorequires, singleton: singleton)
      end

      # Generates the ensurable block with defaultvalues + defaultto :present.
      def self.setup_ensurable(type_class)
        type_class.ensurable do
          defaultvalues
          defaultto :present
        end
      end

      # Generates the :name parameter with namevar and validation.
      def self.setup_name_param(type_class, name_desc)
        type_class.newparam(:name, namevar: true) do
          desc name_desc

          validate do |value|
            unless value.is_a?(String) && !value.empty?
              raise ArgumentError, 'Name must be a non-empty string'
            end
          end
        end
      end

      # Generates the :device parameter with defaultto extraction from title.
      def self.setup_device_param(type_class)
        type_class.newparam(:device) do
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
      end

      # Generates the :config property with validation, insync?, and to_s methods.
      #
      # The insync? implementation depends on insync_mode:
      # - :simple — flat key comparison with optional field/prefix skipping
      # - :deep_match — recursive hash comparison (subset match)
      # - :casecmp — case-insensitive flat comparison
      #
      # Procs for insync? are built outside the property block to keep
      # complexity per method low, then attached via define_method.
      def self.setup_config_property(type_class, config_desc,
                                     insync_mode:, skip_fields:, volatile_fields:,
                                     password_fields:, skip_prefixes:)
        frozen_skip = (skip_fields + volatile_fields).freeze
        frozen_pw = password_fields.freeze
        frozen_pfx = skip_prefixes.freeze

        # Build insync? implementation as a Proc before entering the property
        # block. This keeps each method's complexity under the threshold.
        insync_impl = build_insync_proc(insync_mode, frozen_skip, frozen_pw, frozen_pfx)
        deep_impl = (insync_mode == :deep_match) ? build_deep_match_proc(frozen_pw) : nil
        mode = insync_mode

        type_class.newproperty(:config) do
          desc config_desc

          validate do |value|
            raise ArgumentError, 'config must be a Hash' unless value.is_a?(Hash)
          end

          define_method(:insync?, insync_impl)
          define_method(:deep_match?, deep_impl) if mode == :deep_match
          define_method(:is_to_s) { |current_value| current_value.inspect }
          define_method(:should_to_s) { |new_value| new_value.inspect }
        end
      end

      # Returns a Proc implementing insync? for the :simple comparison mode.
      # Rejects skip_fields, volatile_fields, and prefix-matched fields from
      # comparison; treats password_fields as always in-sync.
      def self.build_insync_proc_simple(frozen_skip, frozen_pw, frozen_pfx)
        proc do |is|
          return false unless is.is_a?(Hash)

          relevant = should.reject do |k, _|
            frozen_skip.include?(k) || frozen_pfx.any? { |p| k.start_with?(p) }
          end
          relevant.all? do |key, val|
            next true if frozen_pw.include?(key)

            is[key].to_s == val.to_s
          end
        end
      end

      # Returns a Proc implementing insync? for the :deep_match mode.
      # Delegates to the deep_match? helper method defined separately.
      def self.build_insync_proc_deep
        proc { |is| deep_match?(is, should) }
      end

      # Returns a Proc implementing insync? for the :casecmp mode.
      # Performs case-insensitive string comparison on all non-skipped fields.
      def self.build_insync_proc_casecmp(frozen_skip)
        proc do |is|
          return false unless is.is_a?(Hash)

          relevant = should.reject { |k, _| frozen_skip.include?(k) }
          relevant.all? do |key, val|
            is[key].to_s.casecmp(val.to_s).zero?
          end
        end
      end

      # Dispatches to the appropriate insync? proc builder based on mode.
      def self.build_insync_proc(mode, frozen_skip, frozen_pw, frozen_pfx)
        case mode
        when :simple then build_insync_proc_simple(frozen_skip, frozen_pw, frozen_pfx)
        when :deep_match then build_insync_proc_deep
        when :casecmp then build_insync_proc_casecmp(frozen_skip)
        end
      end

      # Returns a Proc implementing deep_match? for recursive subset comparison.
      # Only keys present in should_val are checked against is_val.
      # Password fields are skipped (always considered in-sync).
      def self.build_deep_match_proc(frozen_pw)
        proc do |is_val, should_val|
          return false unless is_val.is_a?(Hash) && should_val.is_a?(Hash)

          should_val.all? do |k, v|
            next true if frozen_pw.include?(k)

            v.is_a?(Hash) ? deep_match?(is_val[k], v) : is_val[k].to_s == v.to_s
          end
        end
      end

      # Generates autorequire blocks from the declarative hash.
      # Delegates each entry to register_autorequire for reduced method size.
      def self.setup_autorequires(type_class, autorequires, singleton:)
        is_singleton = singleton
        autorequires.each do |type_symbol, opts|
          register_autorequire(type_class, type_symbol,
                               opts[:field], opts.fetch(:multiple, false), is_singleton)
        end
      end

      # Registers a single autorequire block on the type class.
      #
      # For list types, device is extracted via self[:device].
      # For singleton types, device is self[:name] (the device name IS the title).
      def self.register_autorequire(type_class, type_symbol, field, multiple, singleton)
        type_class.autorequire(type_symbol) do
          device = singleton ? self[:name] : self[:device]
          raw = (self[:config] || {})[field].to_s

          if multiple
            raw.split(',').map(&:strip).reject(&:empty?).map { |s| "#{s}@#{device}" }
          else
            val = raw.strip
            val.empty? ? [] : ["#{val}@#{device}"]
          end
        end
      end

      private_class_method :setup_ensurable, :setup_name_param,
                           :setup_device_param, :setup_config_property,
                           :setup_autorequires, :register_autorequire,
                           :build_insync_proc, :build_insync_proc_simple,
                           :build_insync_proc_deep, :build_insync_proc_casecmp,
                           :build_deep_match_proc
    end
  end
end
