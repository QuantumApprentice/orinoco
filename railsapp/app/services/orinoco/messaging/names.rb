# frozen_string_literal: true

module Orinoco
  module Messaging
    module Names
      BRIDGE_CONTROL_TOPIC = "orinoco.bridge.control"
      OBS_BRIDGE_CONTROL_QUEUE = "orinoco.obs.bridge.control"

      TWITCH_CHAT_MESSAGE_TOPIC = "orinoco.twitch.message.topic"
      TWITCH_CHAT_MESSAGE_QUEUE = "orinoco.twitch.message.queue"
      TWITCH_BRIDGE_CONTROL_QUEUE = "orinoco.twitch.bridge.control"

      OBS_COMMAND_TOPIC = "orinoco.obs.command"
      OBS_BRIDGE_COMMAND_QUEUE = "orinoco.obs.command.bridge"
    end
  end
end
