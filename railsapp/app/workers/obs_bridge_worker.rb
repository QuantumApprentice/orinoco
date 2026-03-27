# app/workers/obs_bridge_worker.rb
class ObsBridgeWorker
  def run
    supervisor.run
  end

  private

  def supervisor
    @supervisor ||= ObsBridge::Supervisor.new(
      state: state,
      control_consumer: control_consumer,
      runtime: runtime,
      signal_queue: signal_queue
    )
  end

  def runtime
    @runtime ||= ObsBridge::Runtime.new(
      state: state,
      inventory_store: inventory_store,
      session_runner: session_runner
    )
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

  def session_runner
    @session_runner ||= ObsBridge::ObswsRequestSessionRunner.new(
      host: config.obs_bridge.obs_host,
      port: config.obs_bridge.obs_port
    )
  end

  def sqs
    @sqs ||= Aws::SQS::Client.new(**config.event_pipeline.aws_client_options)
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
