# frozen_string_literal: true

module ObsBridge
  module ControlMessage
    class Invalid < StandardError; end
    class InvalidPayload < Invalid; end
    class UnknownType < Invalid; end

    Enable = Struct.new(:bridge_id, :command_id, keyword_init: true)
    Disable = Struct.new(:bridge_id, :command_id, keyword_init: true)
    CaptureAll = Struct.new(:bridge_id, :duration_seconds, :command_id, keyword_init: true)
    Refresh = Struct.new(:bridge_id, :command_id, keyword_init: true)
    Ignored = Struct.new(:bridge_id, :actual_bridge_id, :command_id, keyword_init: true)

    module_function

    def parse(payload, expected_bridge_id:)
      data = stringify_keys(payload)
      raise InvalidPayload, "control payload must be a hash" unless data.is_a?(Hash)

      type = data["type"]
      raise InvalidPayload, "control payload missing type" if blank?(type)

      bridge_id = data["bridge_id"] || expected_bridge_id
      command_id = data["command_id"]

      if bridge_id != expected_bridge_id
        return Ignored.new(
          bridge_id: expected_bridge_id,
          actual_bridge_id: bridge_id,
          command_id: command_id
        )
      end

      case type
      when "obs.bridge.enable"
        Enable.new(bridge_id: bridge_id, command_id: command_id)
      when "obs.bridge.disable"
        Disable.new(bridge_id: bridge_id, command_id: command_id)
      when "obs.bridge.capture_all"
        seconds = parse_positive_integer(
          data["duration_seconds"] || data["seconds"] || 900,
          field_name: "duration_seconds"
        )

        CaptureAll.new(
          bridge_id: bridge_id,
          duration_seconds: seconds,
          command_id: command_id
        )
      when "obs.bridge.refresh"
        Refresh.new(bridge_id: bridge_id, command_id: command_id)
      else
        raise UnknownType, "unknown control message type: #{type.inspect}"
      end
    end

    def stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, inner_value), result|
          result[key.to_s] = stringify_keys(inner_value)
        end
      when Array
        value.map { |entry| stringify_keys(entry) }
      else
        value
      end
    end
    private_class_method :stringify_keys

    def parse_positive_integer(value, field_name:)
      integer = Integer(value)
      raise InvalidPayload, "#{field_name} must be positive" unless integer.positive?

      integer
    rescue ArgumentError, TypeError
      raise InvalidPayload, "#{field_name} must be a positive integer"
    end
    private_class_method :parse_positive_integer

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
    private_class_method :blank?
  end
end
