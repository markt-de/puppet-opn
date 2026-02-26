# frozen_string_literal: true

module PuppetX
  module Opn
    # Resolves ModelRelationField UUIDs <-> names for HAProxy resources.
    #
    # Maintains a per-run class-level cache keyed by "device:endpoint" to
    # avoid redundant API calls across providers during a single Puppet run.
    module HaproxyUuidResolver
      UUID_RE = /\A[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/.freeze

      @cache = {}

      # Queries the given endpoint once and builds a bidirectional map:
      #   { uuid => name, name => uuid }
      # Subsequent calls for the same device:endpoint key are no-ops.
      #
      # @param client   [PuppetX::Opn::ApiClient]
      # @param device   [String]
      # @param endpoint [String]
      def self.populate(client, device, endpoint)
        key = "#{device}:#{endpoint}"
        return if @cache.key?(key)

        map = {}
        begin
          response = client.post(endpoint, {})
          rows = response['rows'] || []
          rows.each do |row|
            uuid = row['uuid'].to_s
            name = row['name'].to_s
            next if uuid.empty? || name.empty?

            map[uuid] = name
            map[name] = uuid
          end
        rescue Puppet::Error => e
          Puppet.warning(
            "HaproxyUuidResolver: failed to populate '#{endpoint}' " \
            "for '#{device}': #{e.message}",
          )
        end

        @cache[key] = map
      end

      # Returns a copy of +config+ with each relation-field value translated
      # from UUIDs to names. Falls back to the original value if not found.
      #
      # @param client          [PuppetX::Opn::ApiClient]
      # @param device          [String]
      # @param relation_fields [Hash] field_name => { endpoint:, multiple: }
      # @param config          [Hash]
      # @return [Hash]
      def self.translate_to_names(client, device, relation_fields, config)
        result = config.dup
        relation_fields.each do |field, opts|
          value = result[field]
          next if value.nil? || value.to_s.empty?

          populate(client, device, opts[:endpoint])
          map = @cache["#{device}:#{opts[:endpoint]}"] || {}

          result[field] = if opts[:multiple]
            value.to_s.split(',').map { |item|
              item = item.strip
              map[item] || item
            }.join(',')
          else
            map[value.to_s] || value.to_s
          end
        end
        result
      end

      # Returns a copy of +config+ with each relation-field value translated
      # from names to UUIDs. Raises Puppet::Error if a name cannot be resolved.
      # Values that already match UUID format pass through unchanged.
      #
      # @param client          [PuppetX::Opn::ApiClient]
      # @param device          [String]
      # @param relation_fields [Hash] field_name => { endpoint:, multiple: }
      # @param config          [Hash]
      # @return [Hash]
      def self.translate_to_uuids(client, device, relation_fields, config)
        result = config.dup
        relation_fields.each do |field, opts|
          value = result[field]
          next if value.nil? || value.to_s.empty?

          cache_key = "#{device}:#{opts[:endpoint]}"
          populate(client, device, opts[:endpoint])
          map = @cache[cache_key] || {}

          result[field] = if opts[:multiple]
            value.to_s.split(',').map { |item|
              item = item.strip
              next item if UUID_RE.match?(item)

              resolved = map[item]
              unless resolved
                @cache.delete(cache_key)
                populate(client, device, opts[:endpoint])
                map = @cache[cache_key] || {}
                resolved = map[item]
              end
              unless resolved
                raise Puppet::Error,
                      "HaproxyUuidResolver: cannot resolve '#{item}' to a UUID " \
                      "via '#{opts[:endpoint]}' on '#{device}'"
              end
              resolved
            }.join(',')
          else
            str = value.to_s
            if UUID_RE.match?(str)
              str
            else
              resolved = map[str]
              unless resolved
                @cache.delete(cache_key)
                populate(client, device, opts[:endpoint])
                map = @cache[cache_key] || {}
                resolved = map[str]
              end
              unless resolved
                raise Puppet::Error,
                      "HaproxyUuidResolver: cannot resolve '#{str}' to a UUID " \
                      "via '#{opts[:endpoint]}' on '#{device}'"
              end
              resolved
            end
          end
        end
        result
      end
    end
  end
end
