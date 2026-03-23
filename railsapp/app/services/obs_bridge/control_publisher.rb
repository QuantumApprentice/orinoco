# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module ObsBridge
  class ControlPublisher
    def initialize(
      sqs:,
      queue_url:,
      bridge_id:,
      clock: -> { Time.now.utc },
      uuid_generator: -> { SecureRandom.uuid }
    )
      @sqs = sqs
      @queue_url = queue_url
      @bridge_id = bridge_id
      @clock = clock
      @uuid_generator = uuid_generator
    end

    def start!
      publish!("obs.bridge.enable")
    end

    def stop!
      publish!("obs.bridge.disable")
    end

    def refresh!
      publish!("obs.bridge.refresh")
    end

    def capture_all!(duration_seconds: 900)
      seconds = Integer(duration_seconds)
      raise ArgumentError, "duration_seconds must be positive" unless seconds.positive?

      publish!("obs.bridge.capture_all", duration_seconds: seconds)
    end

    private

    def publish!(type, extra = {})
      payload = {
        type: type,
        bridge_id: @bridge_id,
        command_id: @uuid_generator.call,
        requested_at: @clock.call.utc.iso8601(6)
      }.merge(extra)

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: JSON.generate(payload)
      )

      payload
    end
  end
end
