# frozen_string_literal: true

module ObsBridge
  class Runtime
    def initialize(
      state:,
      inventory_store:,
      session_runner:,
      affordance_host:,
      affordance_context:,
      logger: nil,
      backoff: nil,
      heartbeat_interval: 5.0,
      idle_sleep: 0.1,
      monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      sleeper: ->(seconds) { sleep seconds },
      thread_factory: ->(&block) { Thread.new(&block) }
    )
      @state = state
      @inventory_store = inventory_store
      @session_runner = session_runner
      @affordance_host = affordance_host
      @affordance_context = affordance_context
      @logger = logger || ->(msg) { warn msg }
      @backoff = backoff || Backoff.new(sleeper: sleeper)
      @heartbeat_interval = heartbeat_interval
      @idle_sleep = idle_sleep
      @monotonic_clock = monotonic_clock
      @sleeper = sleeper
      @thread_factory = thread_factory

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
        @thread = @thread_factory.call { run_loop }
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
      enqueue_command!(:refresh_inventory)
    end

    def enqueue_obs_request!(request)
      enqueue_command!(request)
    end

    def running?
      @mutex.synchronize { @running }
    end

    private

    def run_loop
      run_sessions_until_stopped
    ensure
      disconnect_runtime!
      mark_stopped!
    end

    def run_sessions_until_stopped
      until stop_requested?
        with_runtime_failure do
          run_session
        end
      end
    end

    def run_session
      @logger.call("[obs-bridge/runtime] connecting to OBS")

      @session_runner.run do |session|
        @backoff.reset!
        @state.connected!
        @state.heartbeat!

        refresh_inventory_with(session)
        serve_connected_session(session)
      end

      @state.disconnected!
    end

    def serve_connected_session(session)
      next_heartbeat_at = monotonic_now + @heartbeat_interval

      until stop_requested?
        command_result, next_heartbeat_at = run_connected_iteration(
          session,
          next_heartbeat_at
        )

        return if command_result == :stop
      end
    end

    def run_connected_iteration(session, next_heartbeat_at)
      command_result = drain_commands(session)
      return [:stop, next_heartbeat_at] if command_result == :stop

      dispatch_events(session)
      next_heartbeat_at = heartbeat_if_due(monotonic_now, next_heartbeat_at)
      idle_with_session(session)

      [:continue, next_heartbeat_at]
    end

    def drain_commands(session)
      loop do
        command = @command_queue.pop(true)
        result = handle_command(command, session)
        return result if result == :stop
      rescue ThreadError
        return :continue
      end
    end

    def handle_command(command, session)
      case command
      when :stop
        :stop
      when :refresh_inventory
        refresh_inventory_with(session)
        :continue
      when Hash
        apply_obs_request(session, command)
        :continue
      else
        @logger.call("[obs-bridge/runtime] ignoring unknown command #{command.inspect}")
        :continue
      end
    end

    def apply_obs_request(session, request)
      session.apply_request(request)
    end

    def dispatch_events(session)
      return unless session.respond_to?(:poll_events)

      Array(session.poll_events(timeout: 0)).each do |event|
        @affordance_host.dispatch(
          event.fetch("eventType"),
          event: event.fetch("eventData"),
          context: @affordance_context
        )
      end
    end

    def idle_with_session(session)
      if session.respond_to?(:pump_once)
        session.pump_once(timeout: @idle_sleep)
      else
        @sleeper.call(@idle_sleep)
      end
    end

    def heartbeat_if_due(now, next_heartbeat_at)
      return next_heartbeat_at if now < next_heartbeat_at

      @state.heartbeat!
      now + @heartbeat_interval
    end

    def refresh_inventory_with(session)
      inventory = session.fetch_inventory

      @inventory_store.write_snapshot!(
        scenes: inventory.fetch(:scenes),
        scene_items_by_scene: inventory.fetch(:scene_items_by_scene)
      )
    end

    def enqueue_command!(command)
      return false unless running?

      @command_queue << command
      true
    end

    def with_runtime_failure
      yield
    rescue StandardError => e
      raise if stop_requested?

      message = "runtime loop failed: #{e.class}: #{e.message}"
      @state.disconnected!(error: message)
      @logger.call("[obs-bridge/runtime] #{message}")
      @backoff.snooze!(label: "obs-bridge/runtime")
    end

    def disconnect_runtime!
      @state.disconnected!
    end

    def mark_stopped!
      @mutex.synchronize do
        @running = false
        @thread = nil
      end
    end

    def stop_requested?
      @mutex.synchronize { @stop_requested }
    end

    def monotonic_now
      @monotonic_clock.call
    end
  end
end
