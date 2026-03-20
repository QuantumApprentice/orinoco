module ApplicationHelper
  def cx(*parts)
    parts.flatten.compact.reject(&:empty?).join(" ")
  end
end
