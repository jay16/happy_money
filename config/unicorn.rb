# encoding: utf-8
require "redis"
require 'settingslogic'
require File.expand_path('../../app/models/setting.rb', __FILE__) unless defined?(Setting)

# config/unicorn.rb
app_path = File.expand_path('../..', __FILE__)

socket_file = "#{app_path}/tmp/unicorn.sock"
pid_file = "#{app_path}/tmp/pids/unicorn.pid"
old_pid = "#{pid_file}.oldbin"

# Nuke workers after 30 seconds instead of 60 seconds (the default)
timeout(Setting.unicorn.timeout || 30)

worker_processes(Setting.unicorn.worker_processes || 5) # increase or decrease

# Listen on fs socket for better performance
listen(socket_file, backlog: 1024)

# App PID
pid(pid_file)

# By default, the Unicorn logger will write to stderr.
# Additionally, some applications/frameworks log to stderr or stdout,
# so prevent them from going to /dev/null when daemonized here:
stderr_path("#{app_path}/log/unicorn.log")
stdout_path("#{app_path}/log/unicorn.log")

# To save some memory and improve performance
preload_app true

# 如果为 REE，则添加 copy_on_wirte_friendly
# http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
GC.respond_to?(:copy_on_write_friendly=) && GC.copy_on_write_friendly = true

# Force the bundler gemfile environment variable to
# reference the Сapistrano "current" symlink
before_exec do |_|
  ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', File.dirname(__FILE__))
end

before_fork do |server, _|
  # 参考 http://unicorn.bogomips.org/SIGNALS.html
  # 使用 USR2 信号，以及在进程完成后用 QUIT 信号来实现无缝重启
  if File.exist?(old_pid) && server.pid != old_pid
    begin
      Process.kill('QUIT', File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      puts %(Send 'QUIT' signal to unicorn error!)
      # someone else did our job for us
    end
  end

  # DataObjects::Pooling.pools.each(&:dispose) if defined? DataObjects::Pooling
  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  # 禁止 GC，配合后续的 OOB，来减少请求的执行时间
  GC.disable
  # the following is *required* for Rails + "preload_app true",
  defined?(ActiveRecord::Base) && ActiveRecord::Base.establish_connection

  Redis.current.disconnect!
end
