# frozen_string_literal: true

require "obsws"

module ObsBridge
  class ObswsSessionRunner
    def initialize(
      host:,
      port:,
      requests_client_class: OBSWS::Requests::Client,
      events_client_class: OBSWS::Events::Client
    )
      @host = host
      @port = port
      @requests_client_class = requests_client_class
      @events_client_class = events_client_class
    end

    def run(event_types: [])
      @requests_client_class.new(host: @host, port: @port).run do |req|
        events = @events_client_class.new(host: @host, port: @port)
        session = ObswsSession.new(req: req, events: events)

        session.subscribe!(event_types)
        yield session
      ensure
        session&.close
      end
    end
  end
end
