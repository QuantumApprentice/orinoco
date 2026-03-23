redis = Redis.new(url: ENV.fetch("SCOREBOARD_REDIS_URL"))

state = ObsBridge::BridgeState.new(
  redis: redis,
  bridge_id: ENV.fetch("OBS_BRIDGE_ID", "main"),
  default_enabled: false
)

inventory_store = ObsBridge::InventoryStore.new(
  redis: redis,
  bridge_id: ENV.fetch("OBS_BRIDGE_ID", "main")
)

signal_queue = Queue.new

applier = ObsBridge::ControlApplier.new(
  state: state,
  signal_queue: signal_queue
)

sqs = Aws::SQS::Client.new(
  region: "us-east-1",
  endpoint: ENV.fetch("EVENT_PIPELINE_GOAWS_URL"),
  access_key_id: "fake",
  secret_access_key: "fake"
)

control_consumer = ObsBridge::ControlConsumer.new(
  sqs: sqs,
  queue_url: ENV.fetch("OBS_BRIDGE_CONTROL_QUEUE_URL"),
  bridge_id: ENV.fetch("OBS_BRIDGE_ID", "main"),
  applier: applier
)

runtime = ObsBridge::Runtime.new(
  state: state,
  inventory_store: inventory_store,
  session_runner: ObsBridge::ObswsRequestSessionRunner.new(
    host: ENV.fetch("OBS_HOST"),
    port: Integer(ENV.fetch("OBS_PORT", "4455"))
  )
)

supervisor = ObsBridge::Supervisor.new(
  state: state,
  control_consumer: control_consumer,
  runtime: runtime,
  signal_queue: signal_queue
)

supervisor.run
