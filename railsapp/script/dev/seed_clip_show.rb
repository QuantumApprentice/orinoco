# frozen_string_literal: true

# ./dev.sh runner script/dev/seed_clip_show.rb

record = AffordanceConfig.find_or_initialize_by(name: "clip_show")
record.config = {
  "enabled" => true,
  "scenes" => ["Clips"]
}
record.save!

puts "Seeded #{record.inspect}"
