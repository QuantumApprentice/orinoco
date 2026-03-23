# frozen_string_literal: true

module ObsBridge
  class Supervisor
    def initialize(
      state:,
      control_consumer:,
      runtime:,
      signal_queue:,
      logger: nil,
      idle_sleep: 0.1
    )
      @state = state
      @control_consumer = control_consumer
      @runtime = runtime
      @signal_queue = signal_queue
      @logger = logger || ->(msg) { warn msg }
      @idle_sleep = idle_sleep

      @mutex = Mutex.new
      @stop_requested = false
      @running = false
      @control_thread = nil
    end

    def run
      @mutex.synchronize do
        raise "supervisor already running" if @running

        @stop_requested = false
        @running = true
      end

      start_control_thread!
      reconcile_runtime!

      until stop_requested?
        drain_signals
        sleep @idle_sleep
      end
    ensure
      shutdown_runtime
      join_control_thread
      @mutex.synchronize { @running = false }
    end

    def stop!
      @mutex.synchronize do
        @stop_requested = true
      end
    end

    def running?
      @mutex.synchronize { @running }
    end

    private

    def start_control_thread!
      @control_thread = Thread.new do
        @control_consumer.run(stop: -> { stop_requested? })
      rescue StandardError => e
        message = "control consumer failed: #{e.class}: #{e.message}"
        @state.set_last_error!(message)
        @logger.call("[obs-bridge/supervisor] #{message}")
        stop!
      end
    end

    def join_control_thread
      thread = @control_thread
      return unless thread

      thread.join(1)
      @control_thread = nil
    end

    def drain_signals
      loop do
        signal = @signal_queue.pop(true)
        handle_signal(signal)
      rescue ThreadError
        break
      end
    end

    def handle_signal(signal)
      case signal
      when Cmd::Reconcile
        reconcile_runtime!
      when Cmd::RefreshInventory
        refresh_inventory!
      else
        @logger.call("[obs-bridge/supervisor] ignoring unknown signal #{signal.inspect}")
      end
    end

    def reconcile_runtime!
      if @state.desired_enabled?
        start_runtime_unless_running!
      else
        stop_runtime_if_running!
      end
    end

    def start_runtime_unless_running!
      return if @runtime.running?

      @logger.call("[obs-bridge/supervisor] starting runtime")
      @runtime.start!
    rescue StandardError => e
      message = "runtime start failed: #{e.class}: #{e.message}"
      @state.set_last_error!(message)
      @logger.call("[obs-bridge/supervisor] #{message}")
    end

    def stop_runtime_if_running!
      return unless @runtime.running?

      @logger.call("[obs-bridge/supervisor] stopping runtime")
      @runtime.stop!
    rescue StandardError => e
      message = "runtime stop failed: #{e.class}: #{e.message}"
      @state.set_last_error!(message)
      @logger.call("[obs-bridge/supervisor] #{message}")
    end

    def refresh_inventory!
      return unless @runtime.running?

      @logger.call("[obs-bridge/supervisor] refreshing inventory")
      @runtime.refresh_inventory!
    rescue StandardError => e
      message = "inventory refresh failed: #{e.class}: #{e.message}"
      @state.set_last_error!(message)
      @logger.call("[obs-bridge/supervisor] #{message}")
    end

    def shutdown_runtime
      return unless @runtime.running?

      @runtime.stop!
    rescue StandardError => e
      message = "runtime shutdown failed: #{e.class}: #{e.message}"
      @state.set_last_error!(message)
      @logger.call("[obs-bridge/supervisor] #{message}")
    end

    def stop_requested?
      @mutex.synchronize { @stop_requested }
    end
  end
end
