class ChatController < ApplicationController
  def index
    @twitch_configs = TwitchConfig.all
    @messages = redis.lrange("twitch:chat:history",0,-1)
    @messages = @messages.map { |raw|
      JSON.parse(raw, symbolize_names: true)
    }
  end

  def redis
    app_config = Rails.configuration.x
    @redis ||= Redis.new(url: app_config.scoreboard.redis_url)
  end
end
