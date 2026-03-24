# spec/services/obs_bridge/status_broadcaster_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::StatusBroadcaster do
  let(:redis) { instance_double(Redis) }
  let(:status_reader) { instance_double(ObsBridge::StatusReader) }
  let(:bridge_id) { "main" }

  subject(:broadcaster) do
    described_class.new(
      bridge_id: bridge_id,
      redis: redis,
      status_reader: status_reader
    )
  end

  describe "#broadcast!" do
    let(:status_snapshot) do
      {
        status: {
          desired_enabled: true,
          runtime_connected: true,
          runtime_state: "connected",
          inventory_scene_count: 2,
          inventory_refreshed_at: "2026-03-23T18:00:00.000000Z"
        }
      }
    end

    before do
      allow(status_reader).to receive(:snapshot).and_return(status_snapshot)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    end

    it "broadcasts a replacement for the bridge status panel" do
      broadcaster.broadcast!

      expect(status_reader).to have_received(:snapshot)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        "obs_bridge_status:main",
        target: "obs_bridge_status_panel_main",
        partial: "admin/obs_bridges/status_panel",
        locals: {
          bridge_id: "main",
          status: status_snapshot[:status]
        }
      )
    end
  end
end
