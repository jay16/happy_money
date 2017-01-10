# encoding: utf-8
require 'digest/md5'
require 'sinatra/decompile'
require 'sinatra/multi_route'
require 'sinatra/url_for'
require 'lib/sinatra/markup_plugin'

# controller: root base application
class ApplicationController < Sinatra::Base
  register Sinatra::Reloader unless ENV['RACK_ENV'].eql?('production')
  register Sinatra::MarkupPlugin
  register Sinatra::MultiRoute
  register Sinatra::Decompile
  register Sinatra::Flash

  # helpers
  helpers ApplicationHelper
  helpers Sinatra::UrlForHelper

  use AssetHandler

  set :root, ENV['APP_ROOT_PATH']
  set :rack_env, ENV['RACK_ENV']
  set :logger_level, :info
  enable :sessions, :logging, :static, :method_override
  enable :dump_errors, :raise_errors, :show_exceptions unless ENV['RACK_ENV'].eql?('production')

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
    # response.headers['Access-Control-Allow-Methods'] = 'GET'

    @params = params.merge(request_params || {})
    @params = @params.merge(ip: request.ip, browser: request.user_agent)
    @params.deep_symbolize_keys!

    print_format_logger
  end

  not_found do
    respond_with_json({ info: 'route not found', method: request.request_method, url: request.url }, 404)
  end

  error do
    haml :'shared/error', views: ENV['VIEW_PATH']
  end

  protected

  # global functions list
  def app_root_join(path)
    File.join(settings.root, path)
  end

  def app_tmp_join(path)
    File.join(settings.root, 'tmp', path)
  end

  def md5(something)
    Digest::MD5.hexdigest(something.to_s)
  end

  def current_user
    @current_user ||= User.find_by(user_num: request.cookies['authen'] || '')
  end

  def authenticate!
    return if request.cookies['authen']

    response.set_cookie 'path', value: request.url, path: '/', max_age: '600'
    flash[:danger] = '继续操作前请登录.'
    redirect '/login', 302
  end

  def print_format_logger
    logger.info <<-EOF.strip_heredoc
      #{request.request_method} #{request.path} for #{request.ip} at #{Time.now}
      Parameters:
        #{@params}
    EOF
  end

  def request_params(raw_body = request.body)
    body = case raw_body
    when StringIO
     raw_body.string
    when Tempfile,
     # gem#unicorn
     #     change the strtucture of REQUEST
     (defined?(Unicorn) && Unicorn::TeeInput),
     # gem#passenger is ugly!
     #     change the structure of REQUEST
     #     detail at: https://github.com/phusion/passenger/blob/master/lib/phusion_passenger/utils/tee_input.rb
     (defined?(PhusionPassenger) && PhusionPassenger::Utils::TeeInput),
     (defined?(Rack) && Rack::Lint::InputWrapper)

     raw_body.read # if body.respond_to?(:read)
    else
     raw_body.to_str
    end.to_s.strip

    JSON.parse(body) if !body.empty? && body.start_with?('{') && body.end_with?('}')
  rescue => e
    logger.error %(request_params - #{e.message})
  end

  def respond_with_json(hash = {}, code = 200)
    hash[:code] ||= code

    logger.info hash.to_json
    content_type 'application/json', charset: 'utf-8'
    body hash.to_json
    status code
  end

  def halt_with_json(hash = {}, code = 200)
    hash[:code] ||= code
    content_type :json
    halt(code, { 'Content-Type' => 'application/json;charset=utf-8' }, hash.to_json)
  end

  def set_seo_meta(title = '', meta_keywords = '', meta_description = '')
    @page_title       = title
    @meta_keywords    = meta_keywords
    @meta_description = meta_description
  end

  def cache_with_custom_defined(timestamps = [], etag_content = nil)
    return if ENV['RACK_ENV'] == 'development'

    timestamp = timestamps.compact.max
    timestamp ||= (settings.startup_time || Time.now)

    last_modified timestamp
    etag md5(etag_content || timestamp)
  end

  def render_cache_with_redis
    redis_page_key, redis_timestamp_key = request_cache_redis_keys
    if !redis.exists(redis_page_key) && block_given?
      timestamp, render_content = yield
      redis.set(redis_page_key, render_content)
      redis.set(redis_timestamp_key, timestamp || Time.now.to_s)
    end

    cache_with_custom_defined([redis.get(redis_timestamp_key)])
    redis.get(redis_page_key)
  end

  def request_cache_redis_keys
    user_agent_type = 'default'
    if request.user_agent =~ /android/i
      user_agent_type = 'android'
    elsif request.user_agent =~ /iphone|ipad/i
      user_agent_type = 'ios'
    end

    redis_page_key = %(#{request.path}@#{user_agent_type})
    redis_timestamp_key = %(#{redis_page_key}:timestamp)
    [redis_page_key, redis_timestamp_key]
  end

  def read_json_guard(json_path, default_return = [])
    return default_return unless File.exist?(json_path)

    json_hash = JSON.parse(IO.read(json_path))
    return default_return unless json_hash.is_a?(Array)
    json_hash
  rescue
    File.delete(json_path) if File.exist?(json_path)
    default_return
  end

  def json_format?(content)
    ::JSON.parse(content)
    true
  rescue
    false
  end
end
