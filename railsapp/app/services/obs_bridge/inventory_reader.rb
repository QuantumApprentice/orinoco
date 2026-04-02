# frozen_string_literal: true

require "json"

module ObsBridge
  class InventoryReader
    def initialize(redis:, bridge_id:)
      @redis = redis
      @keys = RedisKeys.new(bridge_id: bridge_id)
    end

    def scenes
      parse_json_array(@redis.get(@keys.scenes))
    end

    def scene_items(scene_name)
      return [] if blank?(scene_name)

      parse_json_array(@redis.get(@keys.scene_items(scene_name)))
    end

    def input_placements_by_uuid
      parse_json_object(@redis.get(@keys.input_placements_by_uuid))
    end

    def placements_for_input_uuid(input_uuid)
      return [] if blank?(input_uuid)

      placements = input_placements_by_uuid[input_uuid]
      placements.is_a?(Array) ? placements : []
    end

    private

    def parse_json_array(value)
      return [] if blank?(value)

      parsed = JSON.parse(value)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def parse_json_object(value)
      return {} if blank?(value)

      parsed = JSON.parse(value)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def blank?(value)
      value.nil? || value.empty?
    end
  end
end
