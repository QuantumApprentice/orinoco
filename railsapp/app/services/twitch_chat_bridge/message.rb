# frozen_string_literal: true

module TwitchChatBridge
  class Message
    attr_reader :tags, :emotes, :name, :txt

    def initialize(tags:, emotes:, name:, txt:)
      @tags = tags || {}
      @emotes = emotes || []
      @name = name
      @txt = txt
    end

    def display_name
      tags[:display_name].presence || name
    end

    def as_json(*)
      {
        tags: tags,
        emotes: emotes,
        name: name,
        txt: txt,
        display_name: display_name
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end

    def self.from_json(json)
      data = JSON.parse(json, symbolize_names: true)

      new(
        tags: data.fetch(:tags, {}),
        emotes: data.fetch(:emotes, []),
        name: data.fetch(:name),
        txt: data.fetch(:txt)
      )
    end
  end
end
