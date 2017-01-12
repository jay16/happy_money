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

  #
  # 抽奖
  #
  # - 未选中的号码每次加载界面时，重新打乱
  # - 界面中随机抽取循环显示
  #
  # GET /admin/random
  get '/random' do
    @prizes = redis.smembers('/prizes').map do |prize_with_count|
      prize, count = prize_with_count.split('x')
      prize_count = redis.keys('/members/*').count do |redis_key|
        redis.hget(redis_key, 'prize') == prize
      end

      prize_with_count if prize_count < count.to_i
    end.compact
    @prizes.push('幸运奖') if @prizes.empty?

    make_sure_unhappy_numbers_in_random
    @numbers = redis.smembers('/numbers_to_happy').shuffle

    haml :random, layout: settings.layout
  end

  post '/random' do
    member_key = redis.keys('/members/*').find do |redis_key|
      params[:number] == redis.hget(redis_key, 'rand')
    end

    redis.srem('/numbers_to_happy', params[:number])

    params[:prize] = params[:prize].split('x').first
    if member_key
      redis.hmset(member_key, ['prize', params[:prize]])
      prize_count = redis.keys('/members/*').count do |redis_key|
        redis.hget(redis_key, 'prize') == params[:prize]
      end

      redis_hash = redis.hgetall(member_key)
      flash[:success] = format('%s%sth - %s|%s|%s', params[:prize], prize_count, redis_hash['rand'], redis_hash['name'], redis_hash['organize'])
    else
      flash[:warning] = format('%s 号码未分配，请继续', params[:number])
    end

    redirect to("/random?prize=#{params[:prize]}&timestamp=#{Time.now.to_i}")
  end

  get '/members' do
    haml :members, layout: settings.layout
  end

  get '/config' do
    haml :config, layout: settings.layout
  end

  get '/clean_pages' do
    redis_keys = redis.keys('*@*')
    redis.del(redis_keys) unless redis_keys.empty?

    redirect to('/config')
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

    redirect to('/config')
  end

  get '/align' do
    redis.keys('/members/*').each do |redis_key|
      if params[:force]
        redis.hmset(redis_key, ['rand', redis.spop('/numbers')])
      else
        unless redis.hget(redis_key, 'rand')
          redis.hmset(redis_key, ['rand', redis.spop('/numbers')])
        end
      end
    end

    redirect to('/config')
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
