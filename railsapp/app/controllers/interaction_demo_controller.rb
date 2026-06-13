# frozen_string_literal: true

class InteractionDemoController < ApplicationController
  layout :resolve_layout

  def show
  end

  def starfall
    InteractionDemo::Sequencer.new(effect: :starfall).start!
    respond_without_navigation
  end

  def sunburst
    InteractionDemo::Sequencer.new(effect: :sunburst).start!
    respond_without_navigation
  end

  def wtf
    count = state_store.increment_wtf!
    InteractionDemo::Broadcaster.new.broadcast_counter!(count:)
    respond_without_navigation
  end

  helper_method :interaction_demo_component

  private

  def interaction_demo_component
    InteractionDemoComponent.new(
      overlay: overlay_mode?,
      wtf_count: state_store.wtf_count,
      overlay_url: interaction_demo_url(no_layout: 1),
      setup_command: "bin/rails runner script/interaction_demo_setup.rb"
    )
  end

  def overlay_mode?
    ActiveModel::Type::Boolean.new.cast(params[:no_layout])
  end

  def state_store
    @state_store ||= InteractionDemo::StateStore.new(redis:)
  end

  def redis
    @redis ||= Redis.new(url: Rails.configuration.x.scoreboard.redis_url)
  end

  def respond_without_navigation
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [] }
      format.html { redirect_to interaction_demo_path }
    end
  end

  def resolve_layout
    return false if turbo_frame_request?
    return "overlay" if overlay_mode?

    "application"
  end
end
