# encoding: utf-8
require 'fileutils'
require 'digest/md5'

# Assets Resource
class AssetHandler < Sinatra::Base
  configure do
    enable :logging, :static, :sessions
    enable :method_override
    enable :coffeescript

    set :root,  ENV['APP_ROOT_PATH']
    set :views, ENV['VIEW_PATH']
    set :public_folder, ENV['APP_ROOT_PATH'] + '/app/assets'
    set :js_dir,  ENV['APP_ROOT_PATH'] +  '/app/assets/javascripts'
    set :css_dir, ENV['APP_ROOT_PATH'] + '/app/assets/stylesheets'

    # set :erb, :layout_engine => :erb, :layout => :layout
    set :haml, layout_engine: :haml, layout: :'/app/views/layouts/layout'
    set :cssengine, 'css'
  end
end
