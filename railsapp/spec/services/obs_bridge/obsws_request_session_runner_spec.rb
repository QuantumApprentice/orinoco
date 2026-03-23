# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::ObswsRequestSessionRunner do
  class FakeRequestsClient
    def initialize(host:, port:)
      @host = host
      @port = port
    end

    def run
      yield FakeReq.new
    end
  end

  class FakeReq
    SceneListResponse = Struct.new(:scenes)
    SceneItemListResponse = Struct.new(:scene_items)

    def get_scene_list
      SceneListResponse.new(
        [
          { sceneName: "Clips" },
          { sceneName: "Starting Soon" }
        ]
      )
    end

    def get_scene_item_list(scene_name)
      case scene_name
      when "Clips"
        SceneItemListResponse.new(
          [
            { sceneItemId: 1, sourceName: "fight", sceneItemEnabled: true }
          ]
        )
      when "Starting Soon"
        SceneItemListResponse.new(
          [
            { sceneItemId: 2, sourceName: "countdown", sceneItemEnabled: true }
          ]
        )
      else
        SceneItemListResponse.new([])
      end
    end
  end

  it "yields a session that fetches normalized OBS inventory" do
    runner = described_class.new(
      host: "localhost",
      port: 4455,
      client_class: FakeRequestsClient
    )

    yielded = nil

    runner.run do |session|
      yielded = session.fetch_inventory
    end

    expect(yielded).to eq(
      {
        scenes: [
          { "sceneName" => "Clips" },
          { "sceneName" => "Starting Soon" }
        ],
        scene_items_by_scene: {
          "Clips" => [
            { "sceneItemId" => 1, "sourceName" => "fight", "sceneItemEnabled" => true }
          ],
          "Starting Soon" => [
            { "sceneItemId" => 2, "sourceName" => "countdown", "sceneItemEnabled" => true }
          ]
        }
      }
    )
  end
end
