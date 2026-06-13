# frozen_string_literal: true

module InteractionDemo
  class Sequencer
    STARFALL_DELAYS = [0.0, 0.18, 0.36, 0.54, 0.72, 0.9, 1.08, 1.26, 1.44, 1.62, 1.8, 1.98].freeze
    SUNBURST_DELAYS = [0.0, 0.33, 0.66, 0.99, 1.32, 1.65, 1.98, 2.31].freeze

    def initialize(effect:, broadcaster: Broadcaster.new, thread_factory: ->(&block) { Thread.new(&block) })
      @effect = effect.to_sym
      @broadcaster = broadcaster
      @thread_factory = thread_factory
    end

    def start!
      timeline = effect == :sunburst ? SUNBURST_DELAYS : STARFALL_DELAYS

      @thread_factory.call do
        Rails.application.executor.wrap do
          previous_delay = 0.0

          timeline.each_with_index do |delay, index|
            sleep(delay - previous_delay) if delay > previous_delay
            broadcaster.broadcast_effect!(effect:, sequence: index)
            previous_delay = delay
          end
        end
      end

      true
    end

    private

    attr_reader :effect, :broadcaster
  end
end
