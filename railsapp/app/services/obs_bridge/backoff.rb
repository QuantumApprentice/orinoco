# frozen_string_literal: true

module ObsBridge
  class Backoff
    def initialize(
      min: 0.25,
      max: 8.0,
      factor: 1.7,
      jitter: 0.25,
      sleeper: ->(seconds) { sleep seconds },
      random: Random.new
    )
      @min = min
      @max = max
      @factor = factor
      @jitter = jitter
      @sleeper = sleeper
      @random = random
      @current = min
    end

    def reset!
      @current = @min
    end

    def snooze!(label: nil)
      base = @current
      @current = [@current * @factor, @max].min

      jitter_span = base * @jitter
      offset = (@random.rand * 2.0 * jitter_span) - jitter_span
      actual = [@min, base + offset].max

      warn "[#{label}] reconnecting in #{format('%.2f', actual)}s" if label

      @sleeper.call(actual)
      actual
    end
  end
end
