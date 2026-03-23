# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::Supervisor do
  class FakeRuntime
    attr_reader :start_calls, :stop_calls, :refresh_calls

    def initialize(start_error: nil, stop_error: nil, refresh_error: nil)
      @start_error = start_error
      @stop_error = stop_error
      @refresh_error = refresh_error
      @running = false
      @start_calls = 0
      @stop_calls = 0
      @refresh_calls = 0
    end

    def start!
      raise @start_error if @start_error

      @start_calls += 1
      @running = true
    end

    def stop!
      raise @stop_error if @stop_error

      @stop_calls += 1
      @running = false
    end

    def refresh_inventory!
      raise @refresh_error if @refresh_error

      @refresh_calls += 1
    end

    def running?
      @running
    end
  end

  class FakeControlConsumer
    attr_reader :run_calls

    def initialize(error: nil)
      @error = error
      @run_calls = 0
    end

    def run(stop:)
      @run_calls += 1
      raise @error if @error

      sleep 0.01 until stop.call
    end
  end

  let(:redis) { FakeRedis.new }
  let(:clock_state) { Struct.new(:now).new(Time.utc(2026, 3, 23, 18, 0, 0)) }
  let(:clock) { -> { clock_state.now } }
  let(:state) do
    ObsBridge::BridgeState.new(
      redis: redis,
      bridge_id: "main",
      clock: clock,
      default_enabled: false
    )
  end
  let(:signal_queue) { Queue.new }
  let(:runtime) { FakeRuntime.new }
  let(:control_consumer) { FakeControlConsumer.new }

  subject(:supervisor) do
    described_class.new(
      state: state,
      control_consumer: control_consumer,
      runtime: runtime,
      signal_queue: signal_queue,
      idle_sleep: 0.01
    )
  end

  def run_supervisor_in_thread
    Thread.new { supervisor.run }
  end

  def wait_until(timeout: 1.0)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      return true if yield
      raise "timed out waiting for condition" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def status
    keys = ObsBridge::RedisKeys.new(bridge_id: "main")
    redis.hgetall(keys.status)
  end

  it "does not start the runtime when the bridge is disabled" do
    thread = run_supervisor_in_thread

    wait_until { control_consumer.run_calls == 1 }
    expect(runtime.running?).to be(false)
    expect(runtime.start_calls).to eq(0)

    supervisor.stop!
    thread.join
  end

  it "starts the runtime on boot when the bridge is enabled" do
    state.enable!

    thread = run_supervisor_in_thread

    wait_until { runtime.running? }
    expect(runtime.start_calls).to eq(1)

    supervisor.stop!
    thread.join
  end

  it "starts the runtime when a reconcile signal arrives after enable" do
    thread = run_supervisor_in_thread
    wait_until { control_consumer.run_calls == 1 }

    state.enable!
    signal_queue << ObsBridge::Cmd.reconcile

    wait_until { runtime.running? }
    expect(runtime.start_calls).to eq(1)

    supervisor.stop!
    thread.join
  end

  it "stops the runtime when a reconcile signal arrives after disable" do
    state.enable!

    thread = run_supervisor_in_thread
    wait_until { runtime.running? }

    state.disable!
    signal_queue << ObsBridge::Cmd.reconcile

    wait_until { !runtime.running? }
    expect(runtime.stop_calls).to eq(1)

    supervisor.stop!
    thread.join
  end

  it "refreshes inventory only when the runtime is running" do
    thread = run_supervisor_in_thread
    wait_until { control_consumer.run_calls == 1 }

    signal_queue << ObsBridge::Cmd.refresh_inventory
    sleep 0.05
    expect(runtime.refresh_calls).to eq(0)

    state.enable!
    signal_queue << ObsBridge::Cmd.reconcile
    wait_until { runtime.running? }

    signal_queue << ObsBridge::Cmd.refresh_inventory
    wait_until { runtime.refresh_calls == 1 }

    supervisor.stop!
    thread.join
  end

  it "records runtime start failures in bridge state" do
    broken_runtime = FakeRuntime.new(start_error: StandardError.new("obs exploded"))

    broken_supervisor = described_class.new(
      state: state,
      control_consumer: control_consumer,
      runtime: broken_runtime,
      signal_queue: signal_queue,
      idle_sleep: 0.01
    )

    state.enable!

    thread = Thread.new { broken_supervisor.run }

    wait_until do
      status["last_error"] == "runtime start failed: StandardError: obs exploded"
    end

    expect(broken_runtime.running?).to be(false)

    broken_supervisor.stop!
    thread.join
  end

  it "records refresh failures in bridge state" do
    broken_runtime = FakeRuntime.new(refresh_error: StandardError.new("refresh exploded"))

    broken_supervisor = described_class.new(
      state: state,
      control_consumer: control_consumer,
      runtime: broken_runtime,
      signal_queue: signal_queue,
      idle_sleep: 0.01
    )

    state.enable!

    thread = Thread.new { broken_supervisor.run }
    wait_until { broken_runtime.running? }

    signal_queue << ObsBridge::Cmd.refresh_inventory

    wait_until do
      status["last_error"] == "inventory refresh failed: StandardError: refresh exploded"
    end

    broken_supervisor.stop!
    thread.join
  end

  it "stops the runtime during shutdown" do
    state.enable!

    thread = run_supervisor_in_thread
    wait_until { runtime.running? }

    supervisor.stop!
    thread.join

    expect(runtime.running?).to be(false)
    expect(runtime.stop_calls).to eq(1)
  end

  it "records control consumer failures and requests shutdown" do
    bad_consumer = FakeControlConsumer.new(error: StandardError.new("sqs died"))

    bad_supervisor = described_class.new(
      state: state,
      control_consumer: bad_consumer,
      runtime: runtime,
      signal_queue: signal_queue,
      idle_sleep: 0.01
    )

    thread = Thread.new { bad_supervisor.run }

    wait_until do
      status["last_error"] == "control consumer failed: StandardError: sqs died"
    end

    thread.join
    expect(bad_supervisor.running?).to be(false)
  end
end
