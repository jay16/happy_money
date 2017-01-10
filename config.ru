# encoding: utf-8
require 'unicorn/oob_gc'
require 'unicorn/worker_killer'
require 'unicorn_metrics/middleware'
require 'sidekiq/web'
require './config/boot.rb'

# 每10次请求，才执行一次GC
use Unicorn::OobGC, 10
# Max requests per worker(1000 - 1500)
use Unicorn::WorkerKiller::MaxRequests, 1000, 1500
# Max memory size (RSS) per worker(192M - 256M)
use Unicorn::WorkerKiller::Oom, (192*(1024**2)), (256*(1024**2))

{
  '/'        => 'HomeController',
  '/members' => 'MembersController',
  '/admin'   => 'AdminController'
}.each_pair do |path, mod|
  map(path) { run mod.constantize }
end
