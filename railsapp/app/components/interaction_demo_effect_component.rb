# frozen_string_literal: true

class InteractionDemoEffectComponent < ApplicationComponent
  def initialize(effect:, sequence:)
    @effect = effect.to_sym
    @sequence = sequence.to_i
  end

  private

  attr_reader :effect, :sequence

  def starfall?
    effect == :starfall
  end

  def wrapper_style
    if starfall?
      "left: #{12 + ((sequence * 7) % 76)}vw; --interaction-demo-drift: #{(-14 + ((sequence * 5) % 29))}vw;"
    else
      "left: #{18 + ((sequence * 11) % 64)}vw; top: #{16 + ((sequence * 9) % 48)}vh; --interaction-demo-drift-x: #{(-18 + ((sequence * 6) % 37))}vw; --interaction-demo-drift-y: #{(-16 + ((sequence * 5) % 33))}vh;"
    end
  end

  def wrapper_class
    if starfall?
      "interaction-demo-star"
    else
      "interaction-demo-sun"
    end
  end

  def color
    if starfall?
      %w[#fef08a #fde68a #f5d0fe #bfdbfe #c4b5fd][sequence % 5]
    else
      %w[#f97316 #fb7185 #facc15 #f59e0b #fdba74][sequence % 5]
    end
  end
end
