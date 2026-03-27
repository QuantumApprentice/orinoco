# frozen_string_literal: true

class Admin::ObsBridgesController < ApplicationController
  def show
    @bridge = status_reader.snapshot
  end

  def start
    ObsBridge::StatusWriter.new(
      redis: redis_client,
      bridge_id: "obs"
    ).mark_start_requested

    control_publisher.start!

    redirect_back_to_bridge("Bridge start requested.")
  rescue StandardError => e
    redirect_back_to_bridge("Failed to request bridge start: #{e.message}", alert: true)
  end

  def stop
    ObsBridge::StatusWriter.new(
      redis: redis_client,
      bridge_id: "obs"
    ).mark_stop_requested

    control_publisher.stop!
    redirect_back_to_bridge("Bridge stop requested.")
  rescue StandardError => e
    redirect_back_to_bridge("Failed to request bridge stop: #{e.message}", alert: true)
  end

  def refresh
    control_publisher.refresh!
    redirect_back_to_bridge("Inventory refresh requested.")
  rescue StandardError => e
    redirect_back_to_bridge("Failed to request inventory refresh: #{e.message}", alert: true)
  end

  def capture_all
    duration_seconds = params.fetch(:duration_seconds, 900)
    control_publisher.capture_all!(duration_seconds: duration_seconds)
    redirect_back_to_bridge("Capture-all requested for #{duration_seconds} seconds.")
  rescue StandardError => e
    redirect_back_to_bridge("Failed to request capture-all: #{e.message}", alert: true)
  end

  private

  def bridge_id
    return 'obs'
    # TODO not all bridges are the obs bridge?
    # params[:id].presence || Rails.application.config.x.obs_bridge.bridge_id
  end

  def status_reader
    ObsBridge::StatusReader.new(
      redis: redis_client,
      bridge_id: bridge_id
    )
  end

  def control_publisher
    ObsBridge::ControlPublisher.new(
      sqs: sqs_client,
      queue_url: control_queue_url,
      bridge_id: bridge_id
    )
  end

  def redis_client
    @redis_client ||= Redis.new(url: Rails.application.config.x.scoreboard.redis_url)
  end

  def sqs_client
    @sqs_client ||= Aws::SQS::Client.new(**Rails.configuration.x.event_pipeline.aws_client_options)
  end

  def control_queue_url
    Rails.application.config.x.orinoco.messaging_topology
      .queue_url(Orinoco::Messaging::Names::OBS_BRIDGE_CONTROL_QUEUE)
  end

  def redirect_back_to_bridge(message, alert: false)
    flash_key = alert ? :alert : :notice
    redirect_to admin_obs_bridge_path(bridge_id), flash_key => message
  end
end
