# frozen_string_literal: true

require "uri"

module ObsBridge
  class RedisKeys
    def initialize(bridge_id:)
      @bridge_id = bridge_id
    end

    attr_reader :bridge_id

    def prefix
      "obs:bridge:#{bridge_id}"
    end

    def status
      "#{prefix}:status"
    end

    def scenes
      "#{prefix}:scenes"
    end

    def scene_items(scene_name)
      "#{prefix}:scene:#{escape_segment(scene_name)}:items"
    end

    def input_placements_by_uuid
      "#{prefix}:input_placements_by_uuid"
    end

    private

    def escape_segment(value)
      URI.encode_www_form_component(value.to_s)
    end
  end
end
