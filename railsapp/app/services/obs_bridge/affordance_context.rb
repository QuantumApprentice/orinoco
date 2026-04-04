# frozen_string_literal: true

module ObsBridge
  class AffordanceContext
    attr_reader :inventory, :config, :emit_request

    def initialize(inventory:, config:, emit_request:)
      @inventory = inventory
      @config = config
      @emit_request = emit_request
    end
  end
end
