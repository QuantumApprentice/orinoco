# frozen_string_literal: true

require "json"

module ObsBridge
  class CommandConsumer
    def initialize(
      sqs:,
      queue_url:,
      signal_queue:,
      logger: nil,
      wait_time_seconds: 20,
      max_number_of_messages: 10
    )
      @sqs = sqs
      @queue_url = queue_url
      @signal_queue = signal_queue
      @logger = logger || ->(msg) { warn msg }
      @wait_time_seconds = wait_time_seconds
      @max_number_of_messages = max_number_of_messages
    end

    def run(stop:)
      until stop.call
        receive_messages.each do |message|
          @logger.call("[obs-bridge/command-consumer] message: #{message.class}: #{message.body}")

          request = decode_message_body(message.body)
          @signal_queue << request
          delete_message(message)
        rescue StandardError => e
          @logger.call("[obs-bridge/command-consumer] failed to process message: #{e.class}: #{e.message}")
        end
      end
    end

    private

    def receive_messages
      response = @sqs.receive_message(
        queue_url: @queue_url,
        wait_time_seconds: @wait_time_seconds,
        max_number_of_messages: @max_number_of_messages
      )

      Array(response.messages)
    end

    def delete_message(message)
      @sqs.delete_message(
        queue_url: @queue_url,
        receipt_handle: message.receipt_handle
      )
    end

    def decode_message_body(body)
      parsed = JSON.parse(body)

      parsed =
        if parsed.is_a?(Hash) && parsed.key?("Message")
          JSON.parse(parsed.fetch("Message"))
        else
          parsed
        end

      raise ArgumentError, "expected OBS request hash" unless parsed.is_a?(Hash)

      parsed
    end
  end
end
