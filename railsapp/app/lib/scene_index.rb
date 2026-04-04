class SceneIndex
  def initialize(scene:, logger: nil)
    @scene = scene
    @logger = logger || ->(msg) { warn msg }
    @mtx = Mutex.new
    @by_name = {}
  end

  attr_reader :scene
  attr_reader :by_name

  def refresh!(req)
    fresh = {}
    req.get_scene_item_list(@scene).scene_items.each do |clip|
      fresh[clip[:sourceName]] = clip[:sceneItemId]
    end

    @mtx.synchronize { @by_name = fresh }
    @logger.call("[requests] refreshed scene index for #{@scene} (#{fresh.size})")
  end

  def load_from_inventory!(inventory_reader)
    fresh = {}
    inventory_reader.scene_items(@scene).each do |clip|
      fresh[clip.fetch("sourceName")] = clip.fetch("sceneItemId")
    end

    @mtx.synchronize { @by_name = fresh }
    @logger.call("[inventory] loaded scene index for #{@scene} (#{fresh.size})")
  end

  def id_for(name)
    @mtx.synchronize { @by_name[name] }
  end
end
