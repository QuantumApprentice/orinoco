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

    index = data.index(":")

    if data.start_with?("PING")

      # outmsg = data.
      substr = data[index]

      ws.send("PONG #{substr}")
      puts "PONG"
    end
  end
end
