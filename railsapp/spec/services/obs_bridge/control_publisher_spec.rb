# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe ObsBridge::ControlPublisher do
  let(:sqs) { FakeSqsClient.new }
  let(:clock) { -> { Time.utc(2026, 3, 23, 18, 0, 0) } }
  let(:uuid_generator) { -> { "cmd-123" } }

  subject(:publisher) do
    described_class.new(
      sqs: sqs,
      queue_url: "http://goaws:31040/000000000000/obs_bridge_control",
      bridge_id: "main",
      clock: clock,
      uuid_generator: uuid_generator
    )
  end

  it "publishes a start command as obs.bridge.enable" do
    payload = publisher.start!

    expect(payload).to include(
      type: "obs.bridge.enable",
      bridge_id: "main",
      command_id: "cmd-123"
    )

    expect(JSON.parse(sqs.send_calls.last[:message_body])).to eq(
      "type" => "obs.bridge.enable",
      "bridge_id" => "main",
      "command_id" => "cmd-123",
      "requested_at" => "2026-03-23T18:00:00.000000Z"
    )
  end

  it "publishes a stop command as obs.bridge.disable" do
    publisher.stop!

    expect(JSON.parse(sqs.send_calls.last[:message_body])["type"]).to eq("obs.bridge.disable")
  end

  it "publishes a refresh command" do
    publisher.refresh!

    expect(JSON.parse(sqs.send_calls.last[:message_body])["type"]).to eq("obs.bridge.refresh")
  end

  it "publishes capture-all with a duration" do
    publisher.capture_all!(duration_seconds: 600)

    expect(JSON.parse(sqs.send_calls.last[:message_body])).to include(
      "type" => "obs.bridge.capture_all",
      "duration_seconds" => 600
    )
  end

  it "rejects non-positive capture durations" do
    expect do
      publisher.capture_all!(duration_seconds: 0)
    end.to raise_error(ArgumentError, /positive/)
  end
end
