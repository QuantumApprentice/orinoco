# config/initializers/event_pipeline_config.rb

unless ENV.fetch('SECRET_KEY_BASE_DUMMY', "0") == "1"
  require Rails.root.join("app/services/orinoco/messaging/topology")

  Rails.application.config.to_prepare do
    sns_client = Aws::SNS::Client.new(
      endpoint: ENV.fetch("EVENT_PIPELINE_GOAWS_URL"),
      region: ENV.fetch("AWS_REGION", "us-east-1"),
      access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID", "fake"),
      secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY", "fake")
    )

    sqs_client = Aws::SQS::Client.new(
      endpoint: ENV.fetch("EVENT_PIPELINE_GOAWS_URL"),
      region: ENV.fetch("AWS_REGION", "us-east-1"),
      access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID", "fake"),
      secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY", "fake")
    )

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
      end.ensure!
  end
end
