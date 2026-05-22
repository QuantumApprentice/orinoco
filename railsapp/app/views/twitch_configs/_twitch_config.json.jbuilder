json.extract! twitch_config, :id, :created_at, :updated_at
json.url twitch_config_url(twitch_config, format: :json)
