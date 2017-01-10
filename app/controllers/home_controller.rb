# encoding: utf-8
require 'lib/sinatra/extension_redis'
# root page
class HomeController < ApplicationController
  set :views, ENV['VIEW_PATH'] + '/home'
  set :layout, :'../layouts/layout'
  register Sinatra::Redis

  #
  # 同事的名称列表
  #
  get '/' do
    haml :index, layout: settings.layout
  end
end
