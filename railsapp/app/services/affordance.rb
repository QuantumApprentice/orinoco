# frozen_string_literal: true

class Affordance
  attr_reader :name

  def initialize(name)
    @name = name.to_sym
    @handlers = []

    yield self if block_given?
  end

  def on(event_type, &handler)
    raise ArgumentError, "handler block required" unless block_given?

    @handlers << [event_type.to_s, handler]
  end

  def install_into(host)
    @handlers.each do |event_type, handler|
      host.on(event_type, &handler)
    end
  end
end
