#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

$LOAD_PATH.unshift(File.dirname(__FILE__))

task default: [:environment]

desc 'bundle exec rake task_name RACK_ENV=development'
task environment: 'Gemfile.lock' do
  ENV['RACK_ENV'] ||= 'production'
  ENV['RAILS_ENV'] = ENV['RACK_ENV']
  require File.expand_path('../config/boot.rb', __FILE__)

  Rack::Builder.parse_file File.expand_path('../config.ru', __FILE__)
  # eval 'Rack::Builder.new {( ' + File.read(File.expand_path('../config.ru', __FILE__)) + "\n )}"
end

Dir.glob('lib/tasks/*.rake').each do |rake_file|

  load rake_file
end
