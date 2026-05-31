# frozen_string_literal: true

require "json"
require "aws-sdk-sqs"
require "redis"

module TwitchChatBridge
  class TwitchChatMessageProcessor
    HISTORY_KEY = "twitch:chat:history"
    HISTORY_LIMIT = 250

    def initialize
      @config = Rails.configuration.x
      @topology = @config.orinoco.messaging_topology

      @sqs = Aws::SQS::Client.new(**@config.event_pipeline.aws_client_options)
      @redis = Redis.new(url: @config.scoreboard.redis_url)

      @queue_url = @topology.queue_url(
        Orinoco::Messaging::Names::TWITCH_CHAT_MESSAGE_QUEUE
      )

      @running = true
      puts "twitch chat message processor initialized"
    end

    def run
      install_signal_handlers

      puts "twitch chat message processor started"
      puts "queue: #{@queue_url}"

      while @running
        poll_once
      end

      puts "twitch chat message processor stopped"
    end

    private

    def poll_once
      response = @sqs.receive_message(
        queue_url: @queue_url,
        max_number_of_messages: 10,
        wait_time_seconds: 20,
        visibility_timeout: 30
      )

      response.messages.each do |sqs_message|
        process_sqs_message(sqs_message)
      end
    rescue => e
      warn "[processor] poll failed: #{e.class}: #{e.message}"
      sleep 2
    end

    def process_sqs_message(sqs_message)
      message = decode_message(sqs_message.body)

      return delete_message(sqs_message) if message.nil?

      persist_message(message)
      broadcast_message(message)

      delete_message(sqs_message)
    rescue => e
      warn "[processor] message failed: #{e.class}: #{e.message}"
      warn e.backtrace.first(5).join("\n")
    end

    def decode_message(body)
      envelope = JSON.parse(body)
      message_json = envelope["Message"] || body

      TwitchChatBridge::Message.from_json(message_json)
    rescue JSON::ParserError, KeyError => e
      warn "[processor] invalid chat message: #{e.class}: #{e.message}"
      nil
    end

    def persist_message(message)
      @redis.multi do |tx|
        tx.rpush(HISTORY_KEY, message.to_json)
        tx.ltrim(HISTORY_KEY, -HISTORY_LIMIT, -1)
      end
    end

    def broadcast_message(message)
      Rails.application.reloader.wrap do
        Turbo::StreamsChannel.broadcast_append_to(
          :chat,
          target: "chat_feed",
          partial: "chat/chat_message",
          locals: {
            message: message,
            ChannelName: channel_name
          }
        )
      end
    end

    def delete_message(sqs_message)
      @sqs.delete_message(
        queue_url: @queue_url,
        receipt_handle: sqs_message.receipt_handle
      )
    end

    def channel_name
      @config.twitch.channel_name
    rescue NoMethodError
      ENV.fetch("TWITCH_CHANNEL_NAME", nil)
    end

    def install_signal_handlers
      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          puts "received #{signal}, shutting down..."
          @running = false
        end
      end
    end
  end
end
