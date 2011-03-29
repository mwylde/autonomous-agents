root = File.expand_path(File.dirname(__FILE__))

require 'ruby-processing'
require 'yaml'
require 'set'

require "#{root}/driving/map"
require "#{root}/driving/agent"
require "#{root}/driving/display"
require "#{root}/driving/app"

Driving::App.new :map => "map.json"
