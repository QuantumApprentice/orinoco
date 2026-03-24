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

      existing_scene_names = read_scene_names
      stale_scene_names = existing_scene_names - scene_names

      @redis.pipelined do |pipe|
        pipe.set(@keys.scenes, JSON.generate(normalized_scenes))

        stale_scene_names.each do |scene_name|
          pipe.del(@keys.scene_items(scene_name))
        end

        scene_names.each do |scene_name|
          items = scene_items_by_scene.fetch(scene_name, scene_items_by_scene.fetch(scene_name.to_sym, []))
          pipe.set(@keys.scene_items(scene_name), JSON.generate(normalize_value(items)))
        end

        pipe.hset(@keys.status, "inventory_refreshed_at", now.iso8601(6))
        pipe.hset(@keys.status, "inventory_scene_count", scene_names.length.to_s)
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

    def now
      @clock.call.utc
    end
  end
end
