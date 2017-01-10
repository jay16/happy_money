# encoding: utf-8
require 'rubygems'
require 'digest/md5'

root_path = File.dirname(File.dirname(__FILE__))

# Modiy APP_NAME/RACK_ENV will switch sqlite.db realtime.
ENV['APP_ROOT_PATH'] = root_path
ENV['RACK_ENV'] ||= 'development'
ENV['VIEW_PATH'] = %(#{root_path}/app/views)

begin
  ENV['BUNDLE_GEMFILE'] ||= %(#{root_path}/Gemfile)
  require 'rake'
  require 'bundler'
  Bundler.setup
rescue => e
  puts e.backtrace && exit
end
Bundler.require(:default, ENV['RACK_ENV'])

# execute linux shell command
# return array with command result
# [execute status, execute result]
def run_command(cmd)
  IO.popen(cmd) do |stdout|
    stdout.reject(&:empty?)
  end.unshift($CHILD_STATUS.exitstatus.zero?)
end

# status, *result = run_command('whoami')
# if result[0].strip == 'root'
#   system('chown -R nobody:nobody #{root_path} && chmod -R 777 #{root_path}')
# else
#   warn 'warning: [#{result[0].strip}] can't execute chown/chmod'
# end
ENV['PLATFORM_OS'] = `uname -s`.strip.downcase
ENV['APP_RUNNER'] = `whoami`.strip.downcase

# 扩充require路径数组
# require 文件时会在$:数组中查找是否存在
$LOAD_PATH.unshift(root_path)
$LOAD_PATH.unshift(%(#{root_path}/config))
$LOAD_PATH.unshift(%(#{root_path}/lib/tasks))
%w(controllers helpers models).each do |path|
  $LOAD_PATH.unshift(%(#{root_path}/app/#{path}))
end

require 'lib/utils/boot.rb'
include Utils::Boot

require 'active_support'
require 'active_support/core_ext/string'
require 'active_support/core_ext/hash'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/date'
require 'active_support/core_ext/numeric/time'
require 'active_support/cache'
require 'asset_handler'

# important! Sinatra time zone set.
Time.zone = 'Beijing'

# helper load before controller for will be included into controller
recursion_require('app/models', /\.rb$/, root_path)
recursion_require('app/helpers', /_helper\.rb$/, root_path)
recursion_require('app/controllers', /_controller\.rb$/, root_path, [/^application_/])

ENV['CACHE'] = 'redis' # file, redis, default as realtime
ENV['APP_NAME'] ||= Setting.app_name
ENV['CACHE_NAMESPACE'] ||= Setting.app_name
ENV['REDIS_URL'] ||= Setting.redis_url
ENV['REDIS_PID_PATH'] ||= %(#{root_path}/tmp/pids/redis.pid)
ENV['UNICORN_PID_PATH'] ||= %(#{root_path}/tmp/pids/unicorn.pid)
ENV['STARTUP'] = Time.now.to_s
