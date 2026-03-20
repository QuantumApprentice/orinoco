class ClipShowController < ApplicationController
  def index
    @scenes=SceneList.new()
    @clips=SceneIndex.new(scene:"Clips")
    OBSWS::Requests::Client.new(host: @host, port: @port).run do |req|
      @clips.refresh!(req)
      @scenes.get_all_scenes(req)
    end
  end

  def play
    index_to_play = params[:id]
    clip_name     = params[:clip_name]
    scene_name    = params[:scene_name]

    OBSWS::Requests::Client.new(host: @host, port: @port).run do |req|

      req.set_scene_item_enabled(scene_name, index_to_play.to_i, true)
      req.set_input_audio_monitor_type(clip_name, 'OBS_MONITORING_TYPE_MONITOR_ONLY')

    end

  end

  # make a Hash that has scene name as key
  # and the clips as an Array for the value
  def get_scenes
      @scenes = Hash.new

      OBSWS::Requests::Client.new(host: @host, port: @port).run do |client|
      client.get_scene_list.scenes.each do |scene|
        clip_cache = SceneIndex.new(scene: scene[:sceneName])
        clip_cache.refresh!(client)
        @scenes[scene[:sceneName]] = clip_cache.by_name
      end
    end
  end


end