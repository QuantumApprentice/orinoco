class CreateTwitchConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :twitch_configs do |t|
      t.string :channel_name

      t.timestamps
    end
  end
end
