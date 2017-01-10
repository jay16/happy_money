# encoding: utf-8
# https://github.com/bmizerany/sinatra-redis
# https://github.com/resque/redis-namespace
require 'uri'
require 'redis'
require 'redis-namespace'

module Sinatra
  module RedisHelper
    def redis
      settings.redis
    end
  end

  module Redis
    def redis=(url)
      @redis = nil
      set :redis_url, url
      redis
    end

    def redis(redis_url = ENV['REDIS_URL'], redis_settings = {})
      @redis ||= (
        url = URI(redis_url)

        base_settings = {
          host: url.host,
          port: url.port,
          db: url.path[1..-1],
          password: url.password
        }
        namespace = %(#{ENV['CACHE_NAMESPACE'] || 'ns'}@#{ENV['RACK_ENV']}).to_sym
        ::Redis::Namespace.new(namespace, redis: ::Redis.new(base_settings.merge(redis_settings)))
      )
    end

    protected

    def self.registered(app)
      app.set :redis_url, ENV['REDIS_URL'] || 'redis://127.0.0.1:6379/0'
      # app.set :redis_settings, {}
      app.helpers RedisHelper
    end
  end
end
