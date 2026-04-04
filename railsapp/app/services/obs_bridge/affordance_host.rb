# frozen_string_literal: true

module ObsBridge
  class AffordanceHost
    def initialize
      @handlers_by_event = Hash.new { |hash, key| hash[key] = [] }
    end

    def on(event_type, &handler)
      raise ArgumentError, "handler block required" unless block_given?

      @handlers_by_event[normalize_event_type(event_type)] << handler
    end

    def event_types
      @handlers_by_event.keys
    end

    def dispatch(event_type, event:, context:)
      @handlers_by_event.fetch(normalize_event_type(event_type), []).each do |handler|
        handler.call(event, context)
      end
    end

    private

    def normalize_event_type(event_type)
      event_type.to_s.underscore
    end
  end
end
