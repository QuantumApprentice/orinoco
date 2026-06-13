# frozen_string_literal: true

class InteractionDemoComponent < ApplicationComponent
  EFFECT_STREAM_NAME = "interaction_demo_effects".freeze
  COUNTER_STREAM_NAME = "interaction_demo_counter".freeze
  EVENTS_TARGET = "interaction_demo_events".freeze
  COUNTER_TARGET = "interaction_demo_wtf_counter".freeze
  PREVIEW_COUNTER_TARGET = "interaction_demo_preview_wtf_counter".freeze

  def initialize(overlay:, wtf_count:, overlay_url:, setup_command:)
    @overlay = overlay
    @wtf_count = wtf_count
    @overlay_url = overlay_url
    @setup_command = setup_command
  end

  private

  attr_reader :wtf_count, :overlay_url, :setup_command

  def overlay?
    @overlay
  end

  def stream_name
    EFFECT_STREAM_NAME
  end

  def counter_stream_name
    COUNTER_STREAM_NAME
  end

  def events_target
    EVENTS_TARGET
  end

  def counter_target
    COUNTER_TARGET
  end

  def preview_counter_target
    PREVIEW_COUNTER_TARGET
  end

  def counter_classes
    cx(
      "inline-flex items-center gap-3 rounded-full border px-4 py-2 text-sm font-semibold shadow-sm backdrop-blur",
      "border-gray-200 bg-white/90 text-gray-900",
      "dark:border-gray-700 dark:bg-gray-900/85 dark:text-gray-100"
    )
  end
end
