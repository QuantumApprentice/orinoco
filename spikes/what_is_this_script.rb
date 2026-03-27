#!/usr/bin/env ruby
# frozen_string_literal: true

require 'debug'
require 'obsws'
require 'awesome_print'

$memes = {}
OBSWS::Requests::Client
  .new(host: 'localhost', port: 4455)
  .run do |client|
    client.get_scene_item_list('Clips').scene_items.each do |clip|
      $memes[clip[:sourceName]] = clip[:sceneItemId]
    end
end

def play_clip(clipname)
  OBSWS::Requests::Client
    .new(host: 'localhost', port: 4455)
    .run do |client|
      # ap memes
      client.set_scene_item_enabled('Clips', $memes[clipname], true)
      client.set_input_audio_monitor_type(clipname, 'OBS_MONITORING_TYPE_MONITOR_ONLY')

    # binding.break
  end
end


client = OBSWS::Events::Client
         .new(host: 'localhost', port: 4455)

# clips = ['fight']
clips=['wat','mama','why','cowbell','shaggy','holycow','familystyle']

cycler = clips.cycle

client.on :media_input_playback_ended do |clip|
  ap "Finished playing: #{clip.input_name}"
  OBSWS::Requests::Client
    .new(host: 'localhost', port: 4455)
    .run do |client|
      client.set_scene_item_enabled('Clips', $memes[clip.input_name], false)
    end
  sleep 1
  play_clip(cycler.next)
end

play_clip(clips[-1])

# input = gets
# puts input

# client.run
loop do
  puts 'sleeping'
  sleep 1
  puts 'awaking'
end
