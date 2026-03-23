# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::ControlConsumer do
  Message = Struct.new(:body, :receipt_handle)

  let(:queue_url) { "http://goaws:31040/000000000000/obs_bridge_control" }

  it "long-polls SQS with the configured wait time and max messages" do
    sqs = FakeSqsClient.new(receive_batches: [[]])
    redis = FakeRedis.new
    state = ObsBridge::BridgeState.new(redis: redis, bridge_id: "main", default_enabled: false)
    applier = ObsBridge::ControlApplier.new(state: state)

    consumer = described_class.new(
      sqs: sqs,
      queue_url: queue_url,
      bridge_id: "main",
      applier: applier,
      wait_time_seconds: 20,
      max_number_of_messages: 1
    )

    consumer.run_once

    expect(sqs.receive_calls).to eq(
      [
        {
          queue_url: queue_url,
          max_number_of_messages: 1,
          wait_time_seconds: 20
        }
      ]
    )
  end

  it "applies a valid enable message and deletes it" do
    message = Message.new(
      { type: "obs.bridge.enable", bridge_id: "main" }.to_json,
      "rh-1"
    )

    sqs = FakeSqsClient.new(receive_batches: [[message]])
    redis = FakeRedis.new
    state = ObsBridge::BridgeState.new(redis: redis, bridge_id: "main", default_enabled: false)
    signals = []
    applier = ObsBridge::ControlApplier.new(state: state, signal_queue: signals)

    consumer = described_class.new(
      sqs: sqs,
      queue_url: queue_url,
      bridge_id: "main",
      applier: applier
    )

    expect(consumer.run_once).to eq([message].each { |_m| nil })

    expect(state.desired_enabled?).to be(true)
    expect(signals).to eq([ObsBridge::Cmd.reconcile])
    expect(sqs.delete_calls).to eq(
      [
        {
          queue_url: queue_url,
          receipt_handle: "rh-1"
        }
      ]
    )
  end

  it "drops malformed JSON and deletes the message" do
    message = Message.new("{ nope", "rh-2")

    sqs = FakeSqsClient.new(receive_batches: [[message]])
    redis = FakeRedis.new
    state = ObsBridge::BridgeState.new(redis: redis, bridge_id: "main", default_enabled: false)
    applier = ObsBridge::ControlApplier.new(state: state)

    consumer = described_class.new(
      sqs: sqs,
      queue_url: queue_url,
      bridge_id: "main",
      applier: applier
    )

    consumer.run_once

    expect(sqs.delete_calls).to eq(
      [
        {
          queue_url: queue_url,
          receipt_handle: "rh-2"
        }
      ]
    )
  end

  it "drops unknown message types and deletes the message" do
    message = Message.new(
      { type: "obs.bridge.spaghetti", bridge_id: "main" }.to_json,
      "rh-3"
    )

    sqs = FakeSqsClient.new(receive_batches: [[message]])
    redis = FakeRedis.new
    state = ObsBridge::BridgeState.new(redis: redis, bridge_id: "main", default_enabled: false)
    applier = ObsBridge::ControlApplier.new(state: state)

    consumer = described_class.new(
      sqs: sqs,
      queue_url: queue_url,
      bridge_id: "main",
      applier: applier
    )

    consumer.run_once

    expect(sqs.delete_calls).to eq(
      [
        {
          queue_url: queue_url,
          receipt_handle: "rh-3"
        }
      ]
    )
  end

  it "ignores commands for other bridges and still deletes them" do
    message = Message.new(
      { type: "obs.bridge.enable", bridge_id: "other" }.to_json,
      "rh-4"
    )

    sqs = FakeSqsClient.new(receive_batches: [[message]])
    redis = FakeRedis.new
    state = ObsBridge::BridgeState.new(redis: redis, bridge_id: "main", default_enabled: false)
    applier = ObsBridge::ControlApplier.new(state: state)

    consumer = described_class.new(
      sqs: sqs,
      queue_url: queue_url,
      bridge_id: "main",
      applier: applier
    )

    consumer.run_once

    expect(state.desired_enabled?).to be(false)
    expect(sqs.delete_calls).to eq(
      [
        {
          queue_url: queue_url,
          receipt_handle: "rh-4"
        }
      ]
    )
  end

  it "does not delete a message when the applier raises unexpectedly" do
    message = Message.new(
      { type: "obs.bridge.enable", bridge_id: "main" }.to_json,
      "rh-5"
    )

    sqs = FakeSqsClient.new(receive_batches: [[message]])
    applier = instance_double(ObsBridge::ControlApplier)

    allow(applier).to receive(:apply).and_raise(StandardError, "boom")

    consumer = described_class.new(
      sqs: sqs,
      queue_url: queue_url,
      bridge_id: "main",
      applier: applier
    )

    consumer.run_once

    expect(sqs.delete_calls).to be_empty
  end
end
