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

  #
  # 显示当前同事名称及随机分配的数字
  #
  # GET /members/member_name
  get '/:member_name' do
    haml :member, layout: settings.layout
  end
end
