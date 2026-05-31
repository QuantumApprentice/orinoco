# frozen_string_literal: true

class ChatMessageComponent < ApplicationComponent
  with_collection_parameter :message

  def initialize(message:)
    @message = message
  end
end
