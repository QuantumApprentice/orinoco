class CardComponent < ApplicationComponent
  def initialize(classes: nil)
    @classes = classes
  end

  private

  attr_reader :classes

  def card_classes
    cx(
      "rounded-lg border p-4",
      "border-gray-200 bg-white text-gray-900",
      "dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100",
      classes
    )
  end
end
