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
