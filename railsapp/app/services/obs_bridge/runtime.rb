# frozen_string_literal: true

module ObsBridge
  class Runtime
    def initialize(
      state:,
      inventory_store:,
      session_runner:,
      logger: nil,
      backoff: nil,
      heartbeat_interval: 5.0,
      idle_sleep: 0.1,
      monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      sleeper: ->(seconds) { sleep seconds }
    )
      @state = state
      @inventory_store = inventory_store
      @session_runner = session_runner
      @logger = logger || ->(msg) { warn msg }
      @backoff = backoff || Backoff.new(sleeper: sleeper)
      @heartbeat_interval = heartbeat_interval
      @idle_sleep = idle_sleep
      @monotonic_clock = monotonic_clock
      @sleeper = sleeper

      @mutex = Mutex.new
      @running = false
      @stop_requested = false
      @thread = nil
      @command_queue = Queue.new
    end

    def start!
      @mutex.synchronize do
        raise "runtime already running" if @running

        @running = true
        @stop_requested = false
        @thread = Thread.new { run_loop }
      end
    end

    def stop!
      thread = nil

      @mutex.synchronize do
        return unless @running

        @stop_requested = true
        @command_queue << :stop
        thread = @thread
      end

      thread&.join
    end

    def refresh_inventory!
      return unless running?

      @command_queue << :refresh_inventory
      true
    end

    def running?
      @mutex.synchronize { @running }
    end

    private

    def run_loop
      until stop_requested?
        begin
          @logger.call("[obs-bridge/runtime] connecting to OBS")

          @session_runner.run do |session|
            @backoff.reset!
            @state.connected!
            @state.heartbeat!

            refresh_inventory_with(session)
            connected_loop(session)
          end

          @state.disconnected!
        rescue StandardError => e
          break if stop_requested?

          message = "runtime loop failed: #{e.class}: #{e.message}"
          @state.disconnected!(error: message)
          @logger.call("[obs-bridge/runtime] #{message}")
          @backoff.snooze!(label: "obs-bridge/runtime")
        end
      end
    ensure
      @state.disconnected!
      @mutex.synchronize do
        @running = false
        @thread = nil
      end
    end

    def connected_loop(session)
      next_heartbeat_at = monotonic_now + @heartbeat_interval

      until stop_requested?
        break if drain_commands(session) == :stop

        now = monotonic_now
        if now >= next_heartbeat_at
          @state.heartbeat!
          next_heartbeat_at = now + @heartbeat_interval
        end

        if session.respond_to?(:pump_once)
          session.pump_once(timeout: @idle_sleep)
        else
          @sleeper.call(@idle_sleep)
        end
      end
    end

    def drain_commands(session)
      loop do
        command = @command_queue.pop(true)

        case command
        when :stop
          return :stop
        when :refresh_inventory
          refresh_inventory_with(session)
        else
          @logger.call("[obs-bridge/runtime] ignoring unknown command #{command.inspect}")
        end
      rescue ThreadError
        return :continue
      end
    end

    def refresh_inventory_with(session)
      inventory = session.fetch_inventory

      @inventory_store.write_snapshot!(
        scenes: inventory.fetch(:scenes),
        scene_items_by_scene: inventory.fetch(:scene_items_by_scene)
      )
    end

    def stop_requested?
      @mutex.synchronize { @stop_requested }
    end

    def monotonic_now
      @monotonic_clock.call
    end
  end
end
