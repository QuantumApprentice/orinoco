class ObsBridgeWorker
  def initialize
    @redis = Redis.new(url: ENV.fetch("SCOREBOARD_REDIS_URL"))

    @state = ObsBridge::BridgeState.new(
      redis: @redis,
      bridge_id: ENV.fetch("OBS_BRIDGE_ID", "obs"),
      default_enabled: false
    )

    @inventory_store = ObsBridge::InventoryStore.new(
      redis: @redis,
      bridge_id: ENV.fetch("OBS_BRIDGE_ID", "obs")
    )

    @signal_queue = Queue.new

    @applier = ObsBridge::ControlApplier.new(
      state: @state,
      signal_queue: @signal_queue
    )

    @sqs = Aws::SQS::Client.new(
      region: "us-east-1",
      endpoint: ENV.fetch("EVENT_PIPELINE_GOAWS_URL"),
      access_key_id: "fake",
      secret_access_key: "fake"
    )

    topology = Rails.application.config.x.orinoco.messaging_topology
    queue_url = topology.queue_url(Orinoco::Messaging::Names::OBS_BRIDGE_CONTROL_QUEUE)
    @control_consumer = ObsBridge::ControlConsumer.new(
      sqs: @sqs,
      queue_url: queue_url,
      bridge_id: ENV.fetch("OBS_BRIDGE_ID", "obs"),
      applier: @applier
    )

    @runtime = ObsBridge::Runtime.new(
      state: @state,
      inventory_store: @inventory_store,
      session_runner: ObsBridge::ObswsRequestSessionRunner.new(
        host: ENV.fetch("OBS_HOST"),
        port: Integer(ENV.fetch("OBS_PORT", "4455"))
      )
    )

    @supervisor = ObsBridge::Supervisor.new(
      state: @state,
      control_consumer: @control_consumer,
      runtime: @runtime,
      signal_queue: @signal_queue
    )
  end

  def run
    @supervisor.run
  end
end
