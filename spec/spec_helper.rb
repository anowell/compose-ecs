require 'bundler/setup'
Bundler.setup
require 'json'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'compose-ecs'
