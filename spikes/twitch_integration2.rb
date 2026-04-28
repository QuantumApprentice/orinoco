require 'twitchrb'


# @oauth = Twitch::OAuth.new(
#   client_id: "justinfan69420"
#   client_secret: ""
# )
@client = Twitch::Client.new(
  client_id: "justinfan69420",
  access_token: ""
)
results = @client.channels.followers broadcaster_id: "quantumapprentice"
puts results.total











BASE_URL = "wss://irc-ws.chat.twitch.tv:443"
@connection ||= Faraday.new(BASE_URL) do |conn|
  conn.response "NICK junstinfan6969"
end


def connection
  @connection ||= Faraday.new(BASE_URL) do |conn|
    conn.request :authorization, :Bearer, access_token
    conn.headers = {
      # "User-Agent" => "twitchrb/v#{VERSION} (github.com/deanpcmad/twitchrb)",
      "Client-ID": client_id
    }
    conn.request :json
    conn.response :json, content_type: "application/json"
    conn.adapter adapter, @stubs
  end
end



