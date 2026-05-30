# frozen_string_literal: true
# this is the publisher
require 'faye/websocket'
require 'eventmachine'
# require 'twitchrb'
require 'net/http'

# $channelName        = 'quantumapprentice'
$channelName        = TwitchConfig.first.channel_name
$botName            = "justinfan69420"
$TwitchWebSocketUrl = 'wss://irc-ws.chat.twitch.tv:443'
$_7TV_WebSocketUrl  = "https://7tv.io/v3/emote-sets/global"    #users/twitch/#{channelName}"
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






module TwitchIRC
  Message = Struct.new(
    :tags,
    :prefix,
    :command,
    :params,
    :text,
    :name,
    :msg,

    keyword_init: true
  ) do
    def nick
      return nil unless prefix

      prefix.split("!", 2).first
    end

    def user
      return nil unless prefix&.include?("!")

      prefix.split("!", 2).last.split("@", 2).first
    end

    def host
      return nil unless prefix&.include?("@")

      prefix.split("@", 2).last
    end

    def channel
      params.first
    end

    def txt
      text
    end
  end












  module_function

  def get_7TV_emotes(url)
    # _7TV_ws = Faye::WebSocket::Client.new(url)

    puts("testing : #{url}")
    uri = URI(url)
    test = Net::HTTP.get(uri)
    puts("test: #{test}")

    # _7TV_ws.on :open do |e|
    #   puts "opening 7TV socket"
    #   # _7TV_ws.send("CAP REQ :twitch.tv/commands twitch.tv/tags")
    #   # _7TV_ws.send("NICK justinfan69420")
    #   # _7TV_ws.send("JOIN ##{channelName}")
    # end
  end


  def get_emote_list(emotes)

    if (emotes[:twitch_emotes] == nil)
      return
    end

    emote_arr = []

    emotes[:twitch_emotes].each do |emote_id, pos|
      cdn_url = "https://static-cdn.jtvnw.net/emoticons/v2/"  ##<id>/<format>/<theme_mode>/<"
      out_url = "#{cdn_url}#{emote_id}/default/dark/2.0"

      pos.each do |idx|
        puts("idx: #{idx}")

        emote_arr.push({
          id: emote_id,
          url: out_url,
          start: idx[:startPosition].to_i,
          end: idx[:endPosition].to_i
        })
      end

      emote_arr.sort { |a, b|
        a[:start] - b[:start]
      }
    end

    return emote_arr
  end





  def parse(line)
    rest = line.chomp
    tags = {}
    msg_obj = {}

    # puts("\n================\nline: #{line}")

    if rest.start_with?("@")
      raw_tags, rest = rest.split(" ", 2)
      tags = parse_twitch_tags(raw_tags[1..])
      msg_obj[:tags] = tags

      msg_obj[:emotes] = get_emote_list(tags)
    end

    if rest.start_with?(":")
      raw_prefix, rest = rest.split(" ", 2)
      if (raw_prefix.index('@') == nil)
        # QTODO: send these to event pipeline as non-message event type
        puts("unable to find @: #{raw_prefix}")
        puts("--------------\n#{rest}\n------------")
        return
      end

      name_strt = raw_prefix.index('@') + 1
      name_end  = raw_prefix.index('.', name_strt)
      name      = raw_prefix[name_strt...name_end]

      # QTODO: this needs to be case-insensitive
      msg_idx   = rest.index("#{$channelName}") + "#{$channelName}".length + 2


      if   (name == ":tmi")
        || (name == "#{$botName}")
        || (name == ":#{$botName}")
        || (name.include?("@emote-only=0;"))
        return;
      end

      msg_obj[:name] = name
      msg_obj[:txt]  = rest[msg_idx..-1]

      return msg_obj

      # puts("#{msg_obj[:name]}: #{msg_obj[:txt]}")
    end


    msg = Message.new(
      tags: tags,
      name: name,
      msg: msg_obj,
      # command: command,
      # params: params,
      # text: text
    )



    # puts("#{msg.name}: #{msg.txt}")


  end



  def parse_twitch_tags(raw_tags)
    parsed_tags = {}

    raw_tags.split(";").each_with_object({}) do |pair, out|
      key, val = pair.split("=", 2)

      tag_val = (key[1] == '') ? 0 : val
      # puts("#{key} : #{val} : #{tag_val}")

      case (key)
        when ("emotes")
          # puts("\n=========\nemotes : #{tag_val}\n\n")
          if (tag_val)
            emotes = val.split("/",-1)

            emote_dict = {}

            emotes.each do |e|
              txt_pos = []
              emote_parts = e.split(":")
              positions = emote_parts[1].split(',')
              positions.each do |pos|
                pos_parts = pos.split('-')
                txt_pos.push({
                  startPosition: pos_parts[0],
                  endPosition:   pos_parts[1]
                })
              end

              emote_dict[emote_parts[0]] = txt_pos
            end
            parsed_tags[:twitch_emotes] = emote_dict
          else
            parsed_tags[:twitch_emotes] = 0
          end
        when ("color")
          parsed_tags[:color]            = tag_val != "" ? tag_val : 'pink'
        when ("display-name")
          parsed_tags[:display_name]     = tag_val
        when ("subscriber")           # is user subscribed
          parsed_tags[:subscriber]       = (tag_val == 1)
        when ("custom-reward-id")
          parsed_tags[:custom_reward_id] = tag_val
        when ("user-id")
          parsed_tags[:user_id]          = tag_val
      end
    end

    # puts("#{parsed_tags[:name]} : #{parsed_tags[:color]}")

    return parsed_tags
  end
















  def unescape_tag_value(value)
    return true if value.nil?

    #QTODO: double check which of these is useful
    value
      .gsub("\\s", " ")
      # .gsub("\\:", ";")
      .gsub("\\r", "\r")
      .gsub("\\n", "\n")
      .gsub("\\\\", "\\")
  end
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
      msg = TwitchIRC.parse(data)
      # TwitchIRC.get_7TV_emotes()

      if (msg != nil) then
        puts("#{msg[:name]}: #{msg[:txt]}\n")

      end

    end




    # puts("getting 7TV stuff")
    # TwitchIRC.get_7TV_emotes(_7TV_WebSocketUrl)




    ##QTODO:
    ## we don't want it to blind render every message,
    ## we want a way to be able to intercept the messages,

    ## filter out stuff we don't want to keep,
    ## then forward it into a good messages queue
    # good_msg, bad_msg = chat_filter(msg)


    config = Rails.configuration.x
    topology = config.orinoco.messaging_topology
    sns = Aws::SNS::Client.new(**config.event_pipeline.aws_client_options)
    sns.publish(
      topic_arn: topology.topic_arn(Orinoco::Messaging::Names::TWITCH_CHAT_MESSAGE_TOPIC),
      message: JSON.generate(msg)
    )

    # def TwitchIRC_request_emitter
    #   @twitch_request_emitter ||= lambda do |request|
    #     sns.publish(
    #       topic_arn: topology.topic_arn(Orinoco::Messaging::Names::TWITCH_CHAT_MESSAGE_TOPIC),
    #       message: JSON.generate(request)
    #     )
    #   end
    # end

    # def sns
    #   @sns ||= Aws::SNS::Client.new(**app_config.event_pipeline.aws_client_options)
    # end

    def redis
      app_config = Rails.configuration.x
      @redis ||= Redis.new(url: app_config.scoreboard.redis_url)
    end

    if (msg != nil) then
    ## to then get rendered and pushed into an array on redis
      redis.rpush("twitch:chat:history", msg.to_json)

    ## so we can re-load the history after page navigation
      Rails.application.reloader.wrap do
        Turbo::StreamsChannel.broadcast_append_to(
          :chat,
          target: "chat_feed",
          partial: "chat/chat_message",

          locals: { message: msg, ChannelName: $channelName }
        )
      end
    end


  end
end
