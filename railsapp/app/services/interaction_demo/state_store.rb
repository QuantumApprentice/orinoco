# frozen_string_literal: true

module InteractionDemo
  class StateStore
    WTF_COUNT_KEY = "interaction_demo:wtf_count"

    def initialize(redis:)
      @redis = redis
    end

    def wtf_count
      @redis.get(WTF_COUNT_KEY).to_i
    end

    def increment_wtf!
      @redis.incr(WTF_COUNT_KEY)
    end
  end
end
