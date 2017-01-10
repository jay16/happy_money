# encoding: utf-8
require 'active_support/core_ext/numeric'
# helper: application
module ApplicationHelper
  # flash#success/warning/danger message will show
  # when redirect between action
  def flash_message
    return if !defined?(flash) || flash.empty?

    # hash key must be string
    hash = flash.each_with_object({}) do |(k, v), h|
      h[k.to_s] = v
    end
    # bootstrap#v3 [alert] javascript plugin
    flash.keys.map(&:to_s).grep(/warning|danger|success/).map do |key|
      close = link_to('&times;', '#', class: 'close', 'data-dismiss' => 'alert')
      tag(:div, content: %(#{close}#{hash[key]}), class: %(alert alert-#{key}), role: 'alert')
    end.join
  end

  MOBILE_USER_AGENTS = 'palm|blackberry|nokia|phone|midp|mobi|symbian|chtml|ericsson|minimo|' \
                       'audiovox|motorola|samsung|telit|upg1|windows ce|ucweb|astel|plucker|' \
                       'x320|x240|j2me|sgh|portable|sprint|docomo|kddi|softbank|android|mmp|' \
                       'pdxgw|netfront|xiino|vodafone|portalmmm|sagem|mot-|sie-|ipod|up\\.b|' \
                       'webos|amoi|novarra|cdm|alcatel|pocket|iphone|mobileexplorer|mobile'.freeze
  # check remote client whether is mobile
  # define different layout
  def mobile?
    user_agent = request.user_agent.to_s.downcase

    return false if user_agent =~ /ipad/

    user_agent =~ Regexp.new(MOBILE_USER_AGENTS)
  end

  def android?
    user_agent = request.user_agent.to_s.downcase
    user_agent =~ Regexp.new('android')
  end

  def ios?
    user_agent = request.user_agent.to_s.downcase
    user_agent =~ Regexp.new('iphone|ipad')
  end

  def time_for(value)
    case value
    when :yesterday then Time.now - 24 * 60 * 60
    when :tomorrow  then Time.now + 24 * 60 * 60
    else super
    end
  end

  # generate keywords from obj
  # for js search function
  def keywords(obj)
    dirty_words = %w(ip browser created_at updated_at id)
    obj.class.properties.map(&:name)
       .reject { |v| dirty_words.include?(v.to_s) }
       .map { |var| obj.instance_variable_get(%(@#{var})).to_s }
       .join(' ')
  end

  # 不同层级的页面，路径设置不同
  def render_page_header
    haml :'../layouts/_header'
  end

  def render_page_title
    web_title = Setting.website.title
    web_title = %(#{@page_title} | #{web_title}) if @page_title

    %(<title>#{web_title}</title>)
  end

  def device_name(user_agent)
    return user_agent if user_agent.nil? || user_agent.empty?

    device_infos = user_agent.scan(/\((.*\))/).flatten[0].split(';')
    if %w(ipad iphone).include?(device_infos[0].downcase)
      return device_infos[0]
    else
      return device_infos[-1].split(' ')[0]
    end
  rescue => e
    puts e.message
    return user_agent
  end
end
