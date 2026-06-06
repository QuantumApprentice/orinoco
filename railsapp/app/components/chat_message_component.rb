# frozen_string_literal: true

class ChatMessageComponent < ApplicationComponent
  with_collection_parameter :message

  def initialize(message:)
    @message = message

    if (!message[:twitch_emotes])
      return
    end
    if (!message[:twitch_emotes][0])
      return
    end

    parts = []
    last_idx = message[:txt].length
    message[:twitch_emotes].reverse_each do |emote|
      url       = emote[:url]
      start_idx = emote[:start_idx]
      end_index = emote[:end_index]

      last_half = message[:txt].slice(end_index+1...last_idx)

      parts.unshift(last_half)
      parts.unshift("<img src='#{url}' style='display: inline;'>")
      last_idx = start_idx
    end

    parts.unshift(message[:txt].slice(0...last_idx))
    @message.txt = "#{parts.join('')}"
  end
end
