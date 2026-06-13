# frozen_string_literal: true

class InteractionDemoCounterComponent < ApplicationComponent
  def initialize(count:)
    @count = count.to_i
  end

  private

  attr_reader :count
end
