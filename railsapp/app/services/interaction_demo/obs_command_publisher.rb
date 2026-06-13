# frozen_string_literal: true

require "json"

module InteractionDemo
  class ObsCommandPublisher
    def initialize(sns:, topology:)
      @sns = sns
      @topology = topology
    end

    def publish!(request)
      @sns.publish(
        topic_arn: @topology.topic_arn(Orinoco::Messaging::Names::OBS_COMMAND_TOPIC),
        message: JSON.generate(request)
      )

      request
    end
  end
end
