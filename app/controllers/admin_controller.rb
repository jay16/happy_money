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

  #
  # 抽奖
  #
  # - 未选中的号码每次加载界面时，重新打乱
  # - 界面中随机抽取循环显示
  #
  # GET /admin/random
  get '/random' do
    @prizes = redis.smembers('/prizes').map { |item| item.split('x').first }
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
      flash[:success] = format('%s - %s|%s', params[:prize], redis_hash['name'], redis_hash['organize'])
    else
      flash[:warning] = '未命中'
    end

    redirect to("/random?prize=#{params[:prize]}")
  end

  get '/pages' do
  end
end
