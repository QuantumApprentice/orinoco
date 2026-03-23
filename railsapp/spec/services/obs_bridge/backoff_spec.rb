# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObsBridge::Backoff do
  it "resets to its minimum delay" do
    sleeps = []
    random = Random.new(1234)

    backoff = described_class.new(
      min: 1.0,
      max: 8.0,
      factor: 2.0,
      jitter: 0.0,
      sleeper: ->(seconds) { sleeps << seconds },
      random: random
    )

    backoff.snooze!
    backoff.snooze!
    backoff.reset!
    backoff.snooze!

    expect(sleeps).to eq([1.0, 2.0, 1.0])
  end

  it "caps at its maximum delay" do
    sleeps = []

    backoff = described_class.new(
      min: 1.0,
      max: 3.0,
      factor: 2.0,
      jitter: 0.0,
      sleeper: ->(seconds) { sleeps << seconds }
    )

    4.times { backoff.snooze! }

    expect(sleeps).to eq([1.0, 2.0, 3.0, 3.0])
  end
end
