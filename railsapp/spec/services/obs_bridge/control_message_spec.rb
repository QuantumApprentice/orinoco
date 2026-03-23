# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::ControlMessage do
  describe ".parse" do
    it "parses enable messages" do
      message = described_class.parse(
        { "type" => "obs.bridge.enable", "bridge_id" => "main", "command_id" => "abc123" },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::Enable)
      expect(message.bridge_id).to eq("main")
      expect(message.command_id).to eq("abc123")
    end

    it "parses disable messages" do
      message = described_class.parse(
        { "type" => "obs.bridge.disable", "bridge_id" => "main" },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::Disable)
      expect(message.bridge_id).to eq("main")
    end

    it "parses capture-all with an explicit duration" do
      message = described_class.parse(
        { "type" => "obs.bridge.capture_all", "bridge_id" => "main", "duration_seconds" => 600 },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::CaptureAll)
      expect(message.duration_seconds).to eq(600)
    end

    it "defaults capture-all to 900 seconds" do
      message = described_class.parse(
        { "type" => "obs.bridge.capture_all", "bridge_id" => "main" },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::CaptureAll)
      expect(message.duration_seconds).to eq(900)
    end

    it "parses refresh messages" do
      message = described_class.parse(
        { "type" => "obs.bridge.refresh", "bridge_id" => "main" },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::Refresh)
    end

    it "treats a missing bridge_id as the expected bridge" do
      message = described_class.parse(
        { "type" => "obs.bridge.enable" },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::Enable)
      expect(message.bridge_id).to eq("main")
    end

    it "returns Ignored for commands meant for a different bridge" do
      message = described_class.parse(
        { "type" => "obs.bridge.enable", "bridge_id" => "other" },
        expected_bridge_id: "main"
      )

      expect(message).to be_a(ObsBridge::ControlMessage::Ignored)
      expect(message.bridge_id).to eq("main")
      expect(message.actual_bridge_id).to eq("other")
    end

    it "rejects payloads without a type" do
      expect do
        described_class.parse({ "bridge_id" => "main" }, expected_bridge_id: "main")
      end.to raise_error(ObsBridge::ControlMessage::InvalidPayload, /missing type/)
    end

    it "rejects unknown types" do
      expect do
        described_class.parse(
          { "type" => "obs.bridge.do_a_barrel_roll", "bridge_id" => "main" },
          expected_bridge_id: "main"
        )
      end.to raise_error(ObsBridge::ControlMessage::UnknownType, /unknown control message type/)
    end

    it "rejects non-hash payloads" do
      expect do
        described_class.parse("wat", expected_bridge_id: "main")
      end.to raise_error(ObsBridge::ControlMessage::InvalidPayload, /must be a hash/)
    end

    it "rejects non-positive capture durations" do
      expect do
        described_class.parse(
          { "type" => "obs.bridge.capture_all", "bridge_id" => "main", "duration_seconds" => 0 },
          expected_bridge_id: "main"
        )
      end.to raise_error(ObsBridge::ControlMessage::InvalidPayload, /must be positive/)
    end
  end
end
