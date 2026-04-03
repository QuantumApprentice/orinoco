require 'faye/websocket'
require 'eventmachine'
# require 'json'


channelName        = 'quantumapprentice'
TwitchWebSocketUrl = 'wss://irc-ws.chat.twitch.tv:443'



EM.run do
  ws = Faye::WebSocket::Client.new(TwitchWebSocketUrl)

  ws.on :open do |e|
    puts "opening socket"
    ws.send("NICK justinfan69420")
    ws.send("JOIN ##{channelName}")
  end

  ws.on :message do |e|
    data = e.data
    puts "Received: #{data}"

    if data.start_index?("PING")

      # outmsg = data.
      substr = data.substring

      ws.send("PONG :tmi.twitch.tv")
      puts "PONG"
    end
  end
end
