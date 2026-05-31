# frozen_string_literal: true

# this is the publisher
require "faye/websocket"
require "eventmachine"
# require 'twitchrb'
require "net/http"
require "securerandom"

# $channelName        = 'quantumapprentice'
$channelName        = TwitchConfig.first.channel_name
# $botName            = "justinfan69420"
$botName            = "justinfan#{SecureRandom.random_number(1_000_000)}"
$TwitchWebSocketUrl = "wss://irc-ws.chat.twitch.tv:443"
$_7TV_WebSocketUrl  = "https://7tv.io/v3/emote-sets/global"    # users/twitch/#{channelName}"
$stdout.sync        = true
$stderr.sync        = true


# Meleneth
# in the view, we need this div to hook into
# <div id="chat_feed" class="chat-feed"></div>

# that gives us a static target on the page
# in your script that is parsing the chat, we can broadcast via
# broadcast_append_to(
#   stream_name,
#   target: "chat_feed",
#   partial: "messages/chat_message",
#   locals: { message: message }
# )
# this is _chat_message.html.erb
# <div
#   id="<%= dom_id(message) %>"
#   data-controller="ephemeral"
#   data-ephemeral-delay-value="5000"
#   class="chat-message"
# >
#   <%= message.body %>
# </div>

# and to make those self-delete we need
# // app/javascript/controllers/ephemeral_controller.js
# import { Controller } from "@hotwired/stimulus"

# export default class extends Controller {
#   static values = {
#     delay: { type: Number, default: 5000 }
#   }

#   connect() {
#     this.timeout = setTimeout(() => {
#       this.element.remove()
#     }, this.delayValue)
#   }

#   disconnect() {
#     clearTimeout(this.timeout)
#   }
# }






## spec/lib/chat_parse_spec.rb
# frozen_string_literal: true

# require "rails_helper"

# RSpec.describe ChatParse do
#   describe ".parse_emote_positions" do
#     it "parses a single emote id with multiple ranges" do
#       input = "4352,4-20,24-35"

#       expect(described_class.parse_emote_positions(input)).to eq(
#         {
#           "4352" => [
#             { startPosition: 4, endPosition: 20 },
#             { startPosition: 24, endPosition: 35 }
#           ]
#         }
#       )
#     end
#   end
# end
# # app/lib/chat_parse.rb
# # frozen_string_literal: true

# class ChatParse
#   def self.parse_emote_positions(input)
#     return {} if input.blank?

#     input.split("/").each_with_object({}) do |emote_group, result|
#       parts = emote_group.split(",")
#       emote_id = parts.shift

#       result[emote_id] = parts.map do |range|
#         start_position, end_position = range.split("-").map(&:to_i)

#         {
#           startPosition: start_position,
#           endPosition: end_position
#         }
#       end
#     end
#   end
# end


def app_config
  @app_config ||= Rails.configuration.x
end

def topology
  @topology ||= app_config.orinoco.messaging_topology
end

def sns
  @sns ||= Aws::SNS::Client.new(**app_config.event_pipeline.aws_client_options)
end

EM.run do
  puts("are we walkin here?")

  Tws = Faye::WebSocket::Client.new($TwitchWebSocketUrl)


  Tws.on :open do |e|
    puts "opening Twitch socket"
    Tws.send("CAP REQ :twitch.tv/commands twitch.tv/tags")
    Tws.send("NICK #{$botName}")
    Tws.send("JOIN ##{$channelName}")
  end


  Tws.on :message do |e|
    data = e.data

    index = data.index(":")
    if data.start_with?("PING")
      substr = data[index]
      Tws.send("PONG #{substr}")
      # QTODO: PONG should go to event pipeline as non-message event type
      puts "PONG"
    else
      parser = TwitchChatBridge::IrcMessageParser.new(
        channel_name: $channelName,
        bot_name: $botName
      )

      msg = parser.parse(data)
      # TwitchIRC.get_7TV_emotes()

      if msg != nil then
        puts("#{msg.name}: #{msg.txt}\n")
        sns.publish(
          topic_arn: topology.topic_arn(Orinoco::Messaging::Names::TWITCH_CHAT_MESSAGE_TOPIC),
          message: JSON.generate(msg)
        )
      end
    end

    # puts("getting 7TV stuff")
    # TwitchIRC.get_7TV_emotes(_7TV_WebSocketUrl)

    # #QTODO:
    ## we don't want it to blind render every message,
    ## we want a way to be able to intercept the messages,

    ## filter out stuff we don't want to keep,
    ## then forward it into a good messages queue
    # good_msg, bad_msg = chat_filter(msg)
  end
end
