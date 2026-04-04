# frozen_string_literal: true

ClipShowAffordance = Affordance.new(:clip_show) do |a|
  a.on :media_input_playback_ended do |event, ctx|
    ctx.logger.call("[affordances/clip_show] on_event #{event.fetch("inputUuid")} in scene #{placement.fetch("sceneName")}, hiding")

    ctx.inventory
      .placements_for_input_uuid(event.fetch("inputUuid"))
      .select do |placement|
        ctx.config.enabled_for_scene?(
          name: :clip_show,
          scene_name: placement.fetch("sceneName")
        )
      end
      .each do |placement|
        ctx.logger.call("[affordances/clip_show] media_input_playback_ended: input #{event.fetch("inputUuid")} in scene #{placement.fetch("sceneName")}, hiding")
        ctx.emit_request.call(
          "requestType" => "SetSceneItemEnabled",
          "requestData" => {
            "sceneName" => placement.fetch("sceneName"),
            "sceneItemId" => placement.fetch("sceneItemId"),
            "sceneItemEnabled" => false
          }
        )
      end
  end
end
