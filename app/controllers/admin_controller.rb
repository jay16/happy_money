# encoding: utf-8
require 'lib/sinatra/extension_redis'
# administartor
class AdminController < ApplicationController
  set :views, ENV['VIEW_PATH'] + '/admin'
  set :layout, :'../layouts/layout'
  register Sinatra::Redis

  # GET /admin/
  get '/' do
    haml :index, layout: settings.layout
  end

  get '/members' do
    haml :members, layout: settings.layout
  end

  get '/members' do
    haml :members, layout: settings.layout
  end

  #
  # 抽奖
  #
  # - 未选中的号码每次加载界面时，重新打乱
  # - 界面中随机抽取循环显示
  #
  # GET /admin/random
  get '/random' do
    @prizes = redis.smembers('/prizes').map { |item| item.split('x').first }

    make_sure_unhappy_numbers_in_random
    @numbers = redis.smembers('/numbers_to_happy').shuffle

    haml :random, layout: settings.layout
  end

  post '/random' do
    member_key = redis.keys('/members/*').find do |redis_key|
      params[:number] == redis.hget(redis_key, 'rand')
    end

    redis.srem('/numbers_to_happy', params[:number])

    if member_key
      redis.hmset(member_key, ['prize', params[:prize]])

      redis_hash = redis.hgetall(member_key)
      flash[:success] = format('%s - %s|%s|%s', params[:prize], redis_hash['rand'], redis_hash['name'], redis_hash['organize'])
    else
      flash[:warning] = format('%s 号码未分配，请继续', params[:number])
    end

    redirect to("/random?prize=#{params[:prize]}&timestamp=#{Time.now.to_i}")
  end

  protected

  def make_sure_unhappy_numbers_in_random
    unhappy_numbers = redis.keys('/members/*').map do |redis_key|
      redis.hget(redis_key, 'rand') if redis.hget(redis_key, 'prize').nil?
    end.compact

    puts unhappy_numbers.to_s
    puts redis.smembers('/numbers_to_happy').to_s
    unhappy_numbers.each do |num|
      #
      # SADD:
      #
      # Add the specified members to the set stored at key.
      # Specified members that **are already a member of this set are ignored**.
      # If key does not exist, a new set is created before adding the specified members.
      redis.sadd('/numbers_to_happy', num)
    end
  end
end
