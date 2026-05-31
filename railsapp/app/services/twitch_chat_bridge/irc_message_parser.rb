# frozen_string_literal: true

module TwitchChatBridge
  class IrcMessageParser
    def initialize(channel_name:, bot_name:)
      @channel_name = channel_name
      @bot_name = bot_name
    end

    def parse(line)
      rest = line.chomp
      tags = {}
      emotes = []

      if rest.start_with?("@")
        raw_tags, rest = rest.split(" ", 2)
        return nil if rest.blank?

        tags = parse_twitch_tags(raw_tags[1..])
        emotes = get_emote_list(tags)
      end

      return nil unless rest.start_with?(":")

      raw_prefix, rest = rest.split(" ", 2)
      return nil if raw_prefix.blank? || rest.blank?
      return nil unless raw_prefix.include?("@")

      name_start = raw_prefix.index("@") + 1
      name_end = raw_prefix.index(".", name_start)
      return nil unless name_end

      name = raw_prefix[name_start...name_end]

      channel_idx = rest.downcase.index(@channel_name.downcase)
      return nil unless channel_idx

      msg_idx = channel_idx + @channel_name.length + 2

      return nil if [
        ":tmi",
        @bot_name,
        ":#{@bot_name}"
      ].include?(name)

      return nil if name.include?("@emote-only=0;")

      TwitchChatBridge::Message.new(
        tags: tags,
        emotes: emotes,
        name: name,
        txt: rest[msg_idx..]
      )
    end

    def get_emote_list(emotes)
      return [] unless emotes[:twitch_emotes].present?

      emote_arr = []

      emotes[:twitch_emotes].each do |emote_id, positions|
        cdn_url = "https://static-cdn.jtvnw.net/emoticons/v2/"
        out_url = "#{cdn_url}#{emote_id}/default/dark/2.0"

        positions.each do |idx|
          emote_arr << {
            id: emote_id,
            url: out_url,
            start: idx[:startPosition].to_i,
            end: idx[:endPosition].to_i
          }
        end
      end

      emote_arr.sort_by { |emote| emote[:start] }
    end

    def parse_twitch_tags(raw_tags)
      parsed_tags = {}

      raw_tags.split(";").each do |pair|
        key, val = pair.split("=", 2)
        tag_val = val.presence

        case key
        when "emotes"
          parsed_tags[:twitch_emotes] = parse_emotes_tag(tag_val)
        when "color"
          parsed_tags[:color] = tag_val.presence || "pink"
        when "display-name"
          parsed_tags[:display_name] = tag_val
        when "subscriber"
          parsed_tags[:subscriber] = tag_val == "1"
        when "custom-reward-id"
          parsed_tags[:custom_reward_id] = tag_val
        when "user-id"
          parsed_tags[:user_id] = tag_val
        end
      end

      parsed_tags
    end

    def parse_emotes_tag(tag_val)
      return nil if tag_val.blank?

      tag_val.split("/", -1).each_with_object({}) do |emote, emote_dict|
        emote_id, raw_positions = emote.split(":", 2)
        next if emote_id.blank? || raw_positions.blank?

        emote_dict[emote_id] = raw_positions.split(",").map do |position|
          start_position, end_position = position.split("-", 2)

          {
            startPosition: start_position,
            endPosition: end_position
          }
        end
      end
    end

    def unescape_tag_value(value)
      return true if value.nil?

      value
        .gsub("\\s", " ")
        .gsub("\\r", "\r")
        .gsub("\\n", "\n")
        .gsub("\\\\", "\\")
    end
  end
end
