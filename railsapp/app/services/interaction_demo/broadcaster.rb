# frozen_string_literal: true

module InteractionDemo
  class Broadcaster
    EFFECT_STREAM_NAME = InteractionDemoComponent::EFFECT_STREAM_NAME
    COUNTER_STREAM_NAME = InteractionDemoComponent::COUNTER_STREAM_NAME
    EVENTS_TARGET = InteractionDemoComponent::EVENTS_TARGET
    COUNTER_TARGET = InteractionDemoComponent::COUNTER_TARGET
    PREVIEW_COUNTER_TARGET = InteractionDemoComponent::PREVIEW_COUNTER_TARGET

    def broadcast_effect!(effect:, sequence:)
      Rails.application.reloader.wrap do
        Turbo::StreamsChannel.broadcast_append_to(
          EFFECT_STREAM_NAME,
          target: EVENTS_TARGET,
          layout: false,
          renderable: InteractionDemoEffectComponent.new(effect:, sequence:)
        )
      end
    end

    def broadcast_counter!(count:)
      Rails.application.reloader.wrap do
        Turbo::StreamsChannel.broadcast_update_to(
          COUNTER_STREAM_NAME,
          target: COUNTER_TARGET,
          layout: false,
          renderable: InteractionDemoCounterComponent.new(count:)
        )

        Turbo::StreamsChannel.broadcast_update_to(
          COUNTER_STREAM_NAME,
          target: PREVIEW_COUNTER_TARGET,
          layout: false,
          renderable: InteractionDemoCounterComponent.new(count:)
        )
      end
    end
  end
end
