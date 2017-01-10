# encoding: utf-8
ENV['RACK_ENV'] = 'test'
require File.expand_path '../../config/boot.rb', __FILE__
require File.expand_path '../../lib/sinatra/extension_redis.rb', __FILE__
require File.expand_path '../../lib/sinatra/markup_plugin/tag_helpers.rb', __FILE__
require 'capybara'
require 'capybara/dsl'
require 'capybara/rspec'
require 'capybara/poltergeist'
require 'rack/test'
require 'digest/md5'
require 'factory_girl'
require 'simplecov'

SimpleCov.start
WEB_TITLE = '年会抽奖'.freeze

module RSpecMixin
  include Rack::Test::Methods
  include Capybara::DSL

  Capybara.app, = Rack::Builder.parse_file File.join(ENV['APP_ROOT_PATH'], 'config.ru')

  # brew install phantomjs
  Capybara.javascript_driver = :poltergeist
  Capybara.ignore_hidden_elements = false
  Capybara.register_driver :rack_test do |app|
    Capybara::RackTest::Driver.new(app, headers: { 'HTTP_USER_AGENT' => 'Capybara' })
  end

  def app; Capybara.app; end
end

RSpec.configure do |config|
  config.include RSpecMixin
  config.include FactoryGirl::Syntax::Methods
  # config.syntax = :expect

  # Use color in STDOUT
  # config.color_enabled = true
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate

  # config.order = 'random'
end

RSpec::Sidekiq.configure do |config|
  # Clears all job queues before each example
  config.clear_all_enqueued_jobs = true # default => true

  # Whether to use terminal colours when outputting messages
  config.enable_terminal_colours = true # default => true

  # Warn when jobs are not enqueued to Redis but to a job array
  config.warn_when_jobs_not_processed_by_sidekiq = false # default => true
end

include Sinatra::TagHelpers

def json_parse(body)
  JSON.parse(body).deep_symbolize_keys!
end

def app_root_join(path)
  File.join(ENV['APP_ROOT_PATH'], path)
end

def app_tmp_join(path)
  File.join(ENV['APP_ROOT_PATH'], 'tmp', path)
end
