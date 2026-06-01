# frozen_string_literal: true

class ChatMessageComponent < ApplicationComponent
  with_collection_parameter :message

  def initialize(message:)
    @message = message

    if (message[:emotes][0])
      puts("message[:emotes]: #{message[:emotes]}")
      parts = []
      last_idx = message[:txt].length
      message[:emotes].reverse_each do |emote|
        url       = emote[:url]
        start_idx = emote[:start_idx]
        end_index = emote[:end_index]

        last_half = message[:txt].slice(end_index+1...last_idx)

        parts.unshift(last_half)
        parts.unshift("<img src=#{url} style='display: inline;'></img>")
        last_idx = start_idx

      end
      parts.unshift(message[:txt].slice(0...last_idx))
      @message[:txt] = "#{parts.join('')}"
    end

  end
end
