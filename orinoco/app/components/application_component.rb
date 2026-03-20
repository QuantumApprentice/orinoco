class ApplicationComponent < ViewComponent::Base
  private
  def cx(*parts)
    parts.flatten.compact.reject(&:empty?).join(" ")
  end
end
