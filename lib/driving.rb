root = File.expand_path(File.dirname(__FILE__))

require 'yaml'
require 'set'
if RUBY_ENGINE == 'jruby'
  require 'java'
end

require "#{root}/driving/constants"
require "#{root}/driving/util"
require "#{root}/driving/map"
require "#{root}/driving/socket"
require "#{root}/driving/server_agent"
require "#{root}/driving/remote_agent"
require "#{root}/driving/client_agent"
require "#{root}/driving/app"

Dir.glob("#{root}/driving/agents/*.rb") do |agent|
  require agent
end
