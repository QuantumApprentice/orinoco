#!/usr/bin/env ruby
#this is the reader

require 'json'
require 'aws-sdk-sns'
require 'aws-sdk-sqs'
require 'eventmachine'

app_config = Rails.configuration.x
sqs = Aws::SQS::Client.new(**app_config.event_pipeline.aws_client_options)
topology = Rails.application.config.x.orinoco.messaging_topology

while true do
  msg = sqs.receive_message(
    queue_url: topology.queue_url(Orinoco::Messaging::Names::TWITCH_CHAT_MESSAGE_QUEUE),
    max_number_of_messages: 1,
    wait_time_seconds: 1
  )
  puts(msg)
end


