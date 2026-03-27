# frozen_string_literal: true

module ObsBridge
  class ControlApplier
    def initialize(state:, signal_queue: nil, logger: nil)
      @state = state
      @signal_queue = signal_queue
      @logger = logger || ->(msg) { warn msg }
    end

    def apply(message)
      case message
      when ControlMessage::Enable
        @state.enable!
        signal(Cmd.reconcile)
        :enabled
      when ControlMessage::Disable
        @state.disable!
        signal(Cmd.reconcile)
        :disabled
      when ControlMessage::CaptureAll
        @state.capture_all_for(message.duration_seconds)
        :capture_all
      when ControlMessage::Refresh
        signal(Cmd.refresh_inventory)
        :refresh
      when ControlMessage::Ignored
        @logger.call(
          "[obs-bridge/control] ignoring command for bridge=#{message.actual_bridge_id.inspect}"
        )
        :ignored
      else
        raise ArgumentError, "unknown control message object: #{message.inspect}"
      end
    end

    private

    def signal(command)
      @signal_queue << command if @signal_queue
    end
  end
end
