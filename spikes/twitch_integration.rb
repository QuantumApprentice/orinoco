# ws_twitch.message(`CAP REQ :twitch.tv/commands twitch.tv/tags`)
# ws_twitch.message(`NICK justinfan6969`                        )
# ws_twitch.message(`JOIN #${channelName}`                      )


require 'websocket'
require 'websocket/driver'
require 'socket'
require 'openssl'


TwitchWebSocketUrl = 'wss://irc-ws.chat.twitch.tv:443'
uri = URI.parse(TwitchWebSocketUrl)
puts(uri.host)
puts(uri.port)

soc = TCPSocket.new(uri.host, uri.port)
ctx = OpenSSL::SSL::SSLContext.new
ssl = OpenSSL::SSL::SSLSocket.new(soc, ctx)
ssl.sync_close = true
ssl.connect
puts("state: #{ssl.state}")
puts("socket_url: #{ssl}")

ws_twitch = WebSocket::Driver.client(ssl)

if (ws_twitch.nil?)
  puts "WTFFFF???"
  exit
end

ws_twitch.on(:open) do |e|
  ws_twitch.text("open...")
  puts("Open: #{e.data}")
end
ws_twitch.on(:message) { |e|
  puts "Message: #{e.data}"
}
ws_twitch.on(:close) do |e|
  puts "Closed: #{e.code}"
  exit
end
