require "rails_helper"

RSpec.describe "ClipShows", type: :request do
  let(:obs_client) { instance_double(OBSWS::Requests::Client) }
  let(:req) do
    instance_double(
      "OBS request client",
      set_scene_item_enabled: nil,
      set_input_audio_monitor_type: nil
    )
  end
  let(:scene_index) { instance_double(SceneIndex, refresh!: nil, by_name: {}) }

  before do
    allow(OBSWS::Requests::Client).to receive(:new).and_return(obs_client)
    allow(obs_client).to receive(:run).and_yield(req)
    allow(SceneIndex).to receive(:new).and_return(scene_index)
  end

  describe "GET /index" do
    it "returns http success" do
      get clip_show_index_path

      expect(response).to have_http_status(:success)
      expect(SceneIndex).to have_received(:new).with(scene: "Clips")
      expect(scene_index).to have_received(:refresh!).with(req)
    end
  end

  describe "POST /play" do
    it "returns http success" do
      post clip_show_play_path(
        id: 123,
        clip_name: "fight",
        scene_name: "Clips"
      )

      expect(response).to have_http_status(:success)
      expect(req).to have_received(:set_scene_item_enabled).with("Clips", 123, true)
      expect(req).to have_received(:set_input_audio_monitor_type).with(
        "fight",
        "OBS_MONITORING_TYPE_MONITOR_ONLY"
      )
    end
  end
end
