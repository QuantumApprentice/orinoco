# frozen_string_literal: true

require "json"

class ObsBridgeWorker
  def run
    supervisor.run
  end

  private

  def supervisor
    @supervisor ||= ObsBridge::Supervisor.new(
      state: state,
      control_consumer: control_consumer,
      runtime_factory: method(:build_runtime),
      signal_queue: signal_queue
    )
  end

  def build_runtime
    host = ObsBridge::AffordanceHost.new

    affordances.each do |affordance|
      affordance.install_into(host)
    end

    ObsBridge::Runtime.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: build_session_runner,
      affordance_host: host,
      affordance_context: build_affordance_context
    )
  end

  def build_session_runner
    ObsBridge::ObswsSessionRunner.new(
      host: config.obs_bridge.obs_host,
      port: config.obs_bridge.obs_port
    )
  end

  def build_affordance_context
    Struct.new(:inventory, :config, :emit_request, keyword_init: true).new(
      inventory: inventory_reader,
      config: affordance_config_reader,
      emit_request: obs_request_emitter
    )
  end

  def affordances
    [
      ClipShowAffordance
    ]
  end

  def control_consumer
    @control_consumer ||= ObsBridge::ControlConsumer.new(
      sqs: sqs,
      queue_url: topology.queue_url(Orinoco::Messaging::Names::OBS_BRIDGE_CONTROL_QUEUE),
      bridge_id: bridge_id,
      applier: applier
    )
  end

  def applier
    @applier ||= ObsBridge::ControlApplier.new(
      state: state,
      signal_queue: signal_queue
    )
  end

  def state
    @state ||= ObsBridge::BridgeState.new(
      redis: redis,
      bridge_id: bridge_id,
      default_enabled: config.obs_bridge.default_enabled
    )
  end

  def inventory_store
    @inventory_store ||= ObsBridge::InventoryStore.new(
      redis: redis,
      bridge_id: bridge_id
    )
  end

  def inventory_reader
    @inventory_reader ||= ObsBridge::InventoryReader.new(
      redis: redis,
      bridge_id: bridge_id
    )
  end

  def affordance_config_reader
    @affordance_config_reader ||= Object.new.tap do |reader|
      def reader.enabled_for_scene?(name:, scene_name:)
        record = AffordanceConfig.find_by(name: name.to_s)
        return false unless record

        config = (record.config || {}).deep_stringify_keys
        enabled = ActiveModel::Type::Boolean.new.cast(config["enabled"])
        scenes = Array(config["scenes"]).map(&:to_s)

        enabled && scenes.include?(scene_name.to_s)
      end
    end
  end

  def obs_request_emitter
    @obs_request_emitter ||= lambda do |request|
      sns.publish(
        topic_arn: topology.topic_arn(Orinoco::Messaging::Names::OBS_COMMAND_TOPIC),
        message: JSON.generate(request)
      )
    end
  end

  def sqs
    @sqs ||= Aws::SQS::Client.new(**config.event_pipeline.aws_client_options)
  end

  def sns
    @sns ||= Aws::SNS::Client.new(**config.event_pipeline.aws_client_options)
  end

  def redis
    @redis ||= Redis.new(url: config.scoreboard.redis_url)
  end

  def signal_queue
    @signal_queue ||= Queue.new
  end

  def topology
    config.orinoco.messaging_topology
  end

  def bridge_id
    config.obs_bridge.bridge_id
  end

  def config
    Rails.configuration.x
  end
end
