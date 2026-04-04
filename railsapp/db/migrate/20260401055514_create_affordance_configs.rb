class CreateAffordanceConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :affordance_configs do |t|
      t.string :name, null: false
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end

    add_index :affordance_configs, :name, unique: true
  end
end
