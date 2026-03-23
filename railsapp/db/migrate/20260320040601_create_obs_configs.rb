class CreateObsConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :obs_configs do |t|
      t.string   :host
      t.integer  :port

      t.timestamps
    end
  end
end
