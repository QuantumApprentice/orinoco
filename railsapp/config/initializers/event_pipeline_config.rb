# config/initializers/event_pipeline_config.rb
# config/initializers/event_pipeline_config.rb
return if ENV["SECRET_KEY_BASE_DUMMY"] == "1" || Rails.env.test?

Rails.application.config.x.scoreboard.redis_url =
  ENV.fetch("SCOREBOARD_REDIS_URL")

Rails.application.config.x.event_pipeline.aws_client_options = {
  endpoint: ENV.fetch("EVENT_PIPELINE_GOAWS_URL"),
  region: ENV.fetch("AWS_REGION", "us-east-1"),
  access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID", "fake"),
  secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY", "fake")
}.freeze

require Rails.root.join("app/services/orinoco/messaging/topology")

Rails.application.config.to_prepare do
  opts = Rails.configuration.x.event_pipeline.aws_client_options
  sns_client = Aws::SNS::Client.new(**opts)
  sqs_client = Aws::SQS::Client.new(**opts)

  Rails.application.config.x.orinoco.messaging_topology =
    Orinoco::Messaging::Topology.define(
      sns_client: sns_client,
      sqs_client: sqs_client
    ) do
      topic Orinoco::Messaging::Names::BRIDGE_CONTROL_TOPIC do
        queue Orinoco::Messaging::Names::OBS_BRIDGE_CONTROL_QUEUE,
          visibility_timeout: 30,
          receive_message_wait_time_seconds: 20
      end
      topic Orinoco::Messaging::Names::OBS_COMMAND_TOPIC do
        queue Orinoco::Messaging::Names::OBS_BRIDGE_COMMAND_QUEUE,
          visibility_timeout: 30,
          receive_message_wait_time_seconds: 20
      end
    end.ensure!
end
