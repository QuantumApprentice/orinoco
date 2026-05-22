class ChatController < ApplicationController
  def index
    @twitch_configs = TwitchConfig.all
  end
end
