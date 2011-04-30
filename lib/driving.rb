root = File.expand_path(File.dirname(__FILE__))

require 'yaml'
require 'set'
if RUBY_ENGINE == 'jruby'
  require 'java'
end

require "#{root}/driving/constants"
require "#{root}/driving/util"
require "#{root}/driving/map"
require "#{root}/driving/agent"
require "#{root}/driving/socket"
require "#{root}/driving/remote_agent"
require "#{root}/driving/client_agent"
if RUBY_ENGINE == 'jruby'
  require "#{root}/driving/display"
  require "#{root}/driving/server"
end
require "#{root}/driving/app"

Dir.glob("#{root}/driving/agents/*.rb") do |agent|
  require agent
end
