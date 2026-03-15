#!/usr/bin/env ruby
# frozen_string_literal: true

require 'debug'
require 'obsws'
require 'awesome_print'

require_relative 'orinoco/app/lib/scene_index.rb'

OBSWS::Requests::Client
  .new(host: 'localhost', port: 4455)
  .run do |client|
  client.get_scene_list.scenes.each do |scene|
    ap scene
      clip_cache = SceneIndex.new(scene: scene[:sceneName])
    clip_cache.refresh!(client)
    ap clip_cache.by_name
  end
end
