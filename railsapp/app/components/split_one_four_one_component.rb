class SplitOneFourOneComponent < ApplicationComponent
  renders_one :one
  renders_one :two
  renders_one :six

  def initialize(**html_options)
    @html_options = html_options
  end

  def classes
    cx("flex flex-nowrap", @html_options[:class])
  end
end
