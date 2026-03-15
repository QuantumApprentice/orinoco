#!/usr/bin/env ruby
# frozen_string_literal: true

require 'debug'
require 'obsws'
require 'awesome_print'

OBSWS::Requests::Client
  .new(host: 'localhost', port: 4455)
  .run do |client|
  client.get_scene_list.scenes.each do |scene|
    puts scene
  end
end
