# frozen_string_literal: true

require "json"
require "time"

module ObsBridge
  class InventoryStore
    def initialize(redis:, bridge_id:, clock: -> { Time.now.utc })
      @redis = redis
      @keys = RedisKeys.new(bridge_id: bridge_id)
      @clock = clock
    end

    def write_snapshot!(scenes:, scene_items_by_scene:)
      normalized_scenes = normalize_value(scenes)
      scene_names = normalized_scenes.map { |scene| extract_scene_name(scene) }

      raise ArgumentError, "every scene must have a name" if scene_names.any?(&:nil?)

      normalized_scene_items_by_scene = normalize_scene_items_by_scene(
        scene_names: scene_names,
        scene_items_by_scene: scene_items_by_scene
      )

      input_placements_by_uuid = build_input_placements_by_uuid(
        scene_items_by_scene: normalized_scene_items_by_scene
      )

      existing_scene_names = read_scene_names
      stale_scene_names = existing_scene_names - scene_names

      @redis.pipelined do |pipe|
        pipe.set(@keys.scenes, JSON.generate(normalized_scenes))

        stale_scene_names.each do |scene_name|
          pipe.del(@keys.scene_items(scene_name))
        end

        scene_names.each do |scene_name|
          pipe.set(
            @keys.scene_items(scene_name),
            JSON.generate(normalized_scene_items_by_scene.fetch(scene_name))
          )
        end

        pipe.set(
          @keys.input_placements_by_uuid,
          JSON.generate(input_placements_by_uuid)
        )

        pipe.hset(@keys.status, "inventory_refreshed_at", now.iso8601(6))
        pipe.hset(@keys.status, "inventory_scene_count", scene_names.length.to_s)
        pipe.hset(@keys.status, "inventory_indexed_input_count", input_placements_by_uuid.length.to_s)
      end

      ObsBridge::StatusBroadcaster.new(bridge_id: @keys.bridge_id, redis: @redis).broadcast!
    end

    private

    def read_scene_names
      raw = @redis.get(@keys.scenes)
      return [] if raw.nil? || raw.empty?

      parsed = JSON.parse(raw)
      parsed.map { |scene| extract_scene_name(scene) }.compact
    end

    def normalize_scene_items_by_scene(scene_names:, scene_items_by_scene:)
      scene_names.each_with_object({}) do |scene_name, result|
        items =
          scene_items_by_scene.fetch(scene_name) do
            scene_items_by_scene.fetch(scene_name.to_sym, [])
          end

        result[scene_name] = normalize_value(items)
      end
    end

    def build_input_placements_by_uuid(scene_items_by_scene:)
      scene_items_by_scene.each_with_object({}) do |(scene_name, items), result|
        items.each do |item|
          input_uuid = extract_input_uuid(item)
          next if blank?(input_uuid)

          result[input_uuid] ||= []
          result[input_uuid] << build_input_placement(scene_name: scene_name, item: item)
        end
      end
    end

    def build_input_placement(scene_name:, item:)
      {
        "sceneName" => scene_name,
        "sceneItemId" => extract_scene_item_id(item),
        "sourceName" => extract_source_name(item),
        "sourceUuid" => extract_input_uuid(item),
        "sceneItemEnabled" => extract_scene_item_enabled(item)
      }.compact
    end

    def extract_scene_name(scene)
      case scene
      when String
        scene
      when Hash
        scene["sceneName"] || scene["name"] || scene[:sceneName] || scene[:name]
      else
        nil
      end
    end

    def extract_input_uuid(item)
      fetch_hash_value(item, "sourceUuid", "inputUuid")
    end

    def extract_source_name(item)
      fetch_hash_value(item, "sourceName", "inputName", "name")
    end

    def extract_scene_item_id(item)
      fetch_hash_value(item, "sceneItemId")
    end

    def extract_scene_item_enabled(item)
      fetch_hash_value(item, "sceneItemEnabled")
    end

    def fetch_hash_value(hash, *keys)
      return nil unless hash.is_a?(Hash)

      keys.each do |key|
        string_value = hash[key]
        return string_value unless string_value.nil?

        symbol_value = hash[key.to_sym]
        return symbol_value unless symbol_value.nil?
      end

      nil
    end

    def normalize_value(value)
      case value
      when Array
        value.map { |entry| normalize_value(entry) }
      when Hash
        value.each_with_object({}) do |(key, inner_value), result|
          result[key.to_s] = normalize_value(inner_value)
        end
      else
        value
      end
    end

    def blank?(value)
      value.nil? || value == ""
    end

    def now
      @clock.call.utc
    end
  end
end
