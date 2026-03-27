# frozen_string_literal: true

module ObsBridge
  module Cmd
    Reconcile = Struct.new
    RefreshInventory = Struct.new

    module_function

    def reconcile
      Reconcile.new
    end

    def refresh_inventory
      RefreshInventory.new
    end
  end
end
