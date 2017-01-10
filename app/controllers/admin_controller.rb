# encoding: utf-8
require 'lib/sinatra/extension_redis'
# administartor
class AdminController < ApplicationController
  set :views, ENV['VIEW_PATH'] + '/admin'
  set :layout, :'../layouts/layout'
  register Sinatra::Redis

  # GET /random/
  get '/' do
    haml :index, layout: settings.layout
  end

  # GET /admin/random
  get '/random' do
    haml :random, layout: settings.layout
  end
end
