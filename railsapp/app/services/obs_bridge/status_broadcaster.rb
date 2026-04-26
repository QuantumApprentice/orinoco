# frozen_string_literal: true

module ObsBridge
  class StatusBroadcaster
    def initialize(bridge_id: "obs_bridge", redis:, status_reader: nil)
      @status_reader = status_reader || StatusReader.new(redis: redis, bridge_id: bridge_id)
      @bridge_id = bridge_id
    end

    def broadcast!
      Turbo::StreamsChannel.broadcast_replace_to(
        stream_name,
        target: target,
        partial: "admin/obs_bridges/status_panel",
        locals: {
          bridge_id: @bridge_id,
          status: bridge_status
        }
      )
    end

    private

    attr_reader :bridge_id, :status_reader

    def bridge_status
      status_reader.snapshot[:status]
    end

    def stream_name
      "obs_bridge_status:#{bridge_id}"
    end

    def target
      "obs_bridge_status_panel_#{bridge_id}"
    end
  end
end
