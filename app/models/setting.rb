# encoding: utf-8
# model: setting
class Setting < Settingslogic
  source 'config/setting.yaml'
  namespace ENV['RACK_ENV']
end
