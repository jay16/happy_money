# encoding: utf-8
require 'lib/sinatra/extension_redis'
# root page
class HomeController < ApplicationController
  set :views, ENV['VIEW_PATH'] + '/home'
  set :layout, :'../layouts/layout'
  register Sinatra::Redis

  #
  # 同事的名称列表|规则描述
  #
  get '/' do
    haml :index, layout: settings.layout
  end

  get '/numbers' do
    redis.smembers('/numbers').to_s
  end

  get '/srandmember' do
    redis.srandmember('/numbers').to_s
  end

  get '/refresh' do
    redis.del('/members') if redis.exists('/members')
    Setting.members.map { |line| line.split(/\s*-\s*/).map(&:strip) }.each do |item|
      redis.sadd('/memebers', item.first)
      memer_key = "/members/#{item.first}"
      redis.del(memer_key) if redis.exists(memer_key)
      redis.hmset(memer_key, [
        "name", item.first,
        "organize", item.last
      ])
    end

    redis.del('/numbers') if redis.exists('/numbers')
    (1..(Setting.members.count + 10)).to_a.shuffle.each do |num|
      redis.sadd('/numbers', num)
    end

    redis.del('/numbers_to_happy') if redis.exists('/numbers_to_happy')
    (1..(Setting.members.count + 10)).to_a.shuffle.each do |num|
      redis.sadd('/numbers_to_happy', num)
    end

    redis.del('/prizes') if redis.exists('/prizes')
    Setting.prizes.each do |num|
      redis.sadd('/prizes', num)
    end

    redirect to('/')
  end

  get '/align' do
    redis.keys('/members/*').each do |redis_key|
      puts redis_key
      redis.hmset(redis_key, [
        'rand', redis.spop('/numbers')
      ])
    end

    redirect to('/')
  end
end
