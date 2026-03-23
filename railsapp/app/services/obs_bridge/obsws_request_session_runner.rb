# frozen_string_literal: true

module ObsBridge
  class ObswsRequestSessionRunner
    def initialize(host:, port:, client_class: OBSWS::Requests::Client)
      @host = host
      @port = port
      @client_class = client_class
    end

    def run
      @client_class.new(host: @host, port: @port).run do |req|
        yield ObswsRequestSession.new(req: req)
      end
    end
  end

  class ObswsRequestSession
    def initialize(req:)
      @req = req
    end

    def fetch_inventory
      scenes = normalize_scenes(Array(@req.get_scene_list.scenes))

      scene_items_by_scene = scenes.each_with_object({}) do |scene, result|
        scene_name = scene.fetch("sceneName")
        response = @req.get_scene_item_list(scene_name)
        result[scene_name] = normalize_scene_items(Array(response.scene_items))
      end

      {
        scenes: scenes,
        scene_items_by_scene: scene_items_by_scene
      }
    end

    def pump_once(timeout:)
      sleep timeout
    end

    private

    def normalize_scenes(raw_scenes)
      raw_scenes.map do |scene|
        {
          "sceneName" => fetch_value(scene, :sceneName, "sceneName", :name, "name")
        }
      end
    end

    def normalize_scene_items(raw_items)
      raw_items.map do |item|
        {
          "sceneItemId" => fetch_value(item, :sceneItemId, "sceneItemId", :id, "id"),
          "sourceName" => fetch_value(item, :sourceName, "sourceName", :inputName, "inputName", :name, "name"),
          "sceneItemEnabled" => fetch_value(item, :sceneItemEnabled, "sceneItemEnabled", :enabled, "enabled")
        }.compact
      end
    end

    def fetch_value(object, *keys)
      keys.each do |key|
        if object.respond_to?(:key?) && object.key?(key)
          return object[key]
        end

        return object.public_send(key) if object.respond_to?(key)
      end

      nil
    end
  end
end
