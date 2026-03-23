# frozen_string_literal: true

require "json"
require "time"

module ObsBridge
  class StatusReader
    def initialize(redis:, bridge_id:)
      @redis = redis
      @keys = RedisKeys.new(bridge_id: bridge_id)
    end

    def snapshot
      scenes = read_scenes

      {
        bridge_id: @keys.bridge_id,
        status: read_status,
        scenes: scenes.map do |scene|
          scene_name = extract_scene_name(scene)

          {
            "sceneName" => scene_name,
            "raw" => scene,
            "items" => read_scene_items(scene_name)
          }
        end
      }
    end

    private

    def read_status
      raw = @redis.hgetall(@keys.status)

      {
        bridge_id: raw["bridge_id"] || @keys.bridge_id,
        desired_state: raw["desired_state"] || "disabled",
        runtime_state: raw["runtime_state"] || "down",
        connected: truthy?(raw["connected"]),
        capture_all_active: truthy?(raw["capture_all_active"]),
        capture_all_until: parse_time(raw["capture_all_until"]),
        last_error: blank_to_nil(raw["last_error"]),
        last_heartbeat_at: parse_time(raw["last_heartbeat_at"]),
        inventory_refreshed_at: parse_time(raw["inventory_refreshed_at"]),
        inventory_scene_count: integer_or_zero(raw["inventory_scene_count"]),
        updated_at: parse_time(raw["updated_at"])
      }
    end

    def read_scenes
      parse_json_array(@redis.get(@keys.scenes))
    end

    def read_scene_items(scene_name)
      return [] if scene_name.nil? || scene_name.empty?

      parse_json_array(@redis.get(@keys.scene_items(scene_name)))
    end

    def parse_json_array(value)
      return [] if value.nil? || value.empty?

      parsed = JSON.parse(value)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def extract_scene_name(scene)
      case scene
      when String
        scene
      when Hash
        scene["sceneName"] || scene["name"] || scene[:sceneName] || scene[:name]
      end
    end

    def truthy?(value)
      value.to_s == "true"
    end

    def integer_or_zero(value)
      Integer(value || 0)
    rescue ArgumentError, TypeError
      0
    end

    def parse_time(value)
      return nil if value.nil? || value.empty?

      Time.iso8601(value)
    rescue ArgumentError
      nil
    end

    def blank_to_nil(value)
      value.nil? || value.empty? ? nil : value
    end
  end
end
