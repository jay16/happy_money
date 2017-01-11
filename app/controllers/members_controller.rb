# encoding: utf-8
require 'lib/sinatra/extension_redis'
# members
class MembersController < ApplicationController
  set :views, ENV['VIEW_PATH'] + '/members'
  set :layout, :'../layouts/layout'
  register Sinatra::Redis

  #
  # 输入用户名
  #   - 存在则跳转至显示随机号码界面
  #   - 不存在则提示用户名不存在
  #
  # GET /members/
  get '/' do
    haml :index, layout: settings.layout
  end

  post '/' do
    member_name = (params[:name] || '').strip
    to_path = ''

    if member_name.strip.empty?
      flash[:warning] = "请输入用户名"
    elsif redis.exists("/members/#{member_name}")
      rand_key = redis.hget("/members/#{member_name}", "rand")
      align_member_rand_number(member_name) unless rand_key

      flash[:success] = "静候佳音"
      to_path = "/#{member_name}"
    else
      flash[:warning] = "请确认输入的名称"
    end

    redirect to(to_path)
  end

  #
  # 显示当前同事名称及随机分配的数字
  #
  # GET /members/member_name
  get '/:member_name' do
    member_key = "/members/#{params[:member_name]}"

    if redis.exists(member_key) && redis.hget(member_key, 'rand')
      @member = redis.hgetall(member_key)

      haml :member, layout: settings.layout
    else
      flash[:warning] = "#{params[:member_name]} 未分配号码，请输入用户名"

      redirect to('/')
    end
  end

  protected

  def align_member_rand_number(member_name, try_num = 0)
    rand_key = redis.spop('/numbers')
    if rand_key
      redis.hmset("/members/#{member_name}", [
        'rand', rand_key
      ])
    end
    true
  rescue => e
    if try_num < 3
      align_member_rand_number(member_name, try_num + 1)
    else
      puts e.message
      return false
    end
  end
end
