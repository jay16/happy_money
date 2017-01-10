# encoding: utf-8
require 'json'
require 'faraday'
require 'digest/md5'

# methods around umeng push message to mobile devices
module UMengPush
  module Methods
    UMENG_API_HOST = 'http://msg.umeng.com'.freeze
    UMENT_API_STATUS_METHOD = 'POST'.freeze
    UMENG_API_SEND_METHOD = 'POST'.freeze

    # http://dev.umeng.com/push/ios/api-doc#4_10
    # 当消息发送的类型为任务时，包括 "broadcast","groupcast", "filecast","customizedcast(通过 file_id 传参)" 时, 可以通过 "task_id" 来查询当前的消息状态。
    # 注意，当次发送任务如果发送总量小于 500 个的话，后台会按照列播的方式推送，不再按照任务的方式来处理。 该接口会不生效。
    def umeng_task_query(push_type, app_key, app_master_secret, timestamp, task_id)
      unless %w(broadcast groupcast filecast customizedcast).include?(push_type)
        return { data: { error_code: %(消息推送类型(#{push_type})不支持查询) }}.to_json
      end

      conn = Faraday.new(url: UMENG_API_HOST) do |faraday|
        faraday.request  :url_encoded
        faraday.adapter  Faraday.default_adapter
      end

      push_params = { appkey: app_key, timestamp: timestamp.to_i, task_id: task_id }
      puts push_params.to_json
      url = %(#{UMENG_API_HOST}/api/status)
      sign = md5([UMENT_API_STATUS_METHOD, url, JSON.dump(push_params), app_master_secret].join)
      response = conn.post do |req|
        req.url 'api/status', sign: sign
        req.headers['Content-Type'] = 'application/json'
        req.body = push_params.to_json
      end

      res = JSON.parse(response.body)
      res
    end

    def umeng_push_message(platform, push_type, app_key, app_master_secret, params, custom_keys = {}, device_tokens = '')
      return if push_type != 'broadcast' && device_tokens.empty?

      url = %(#{UMENG_API_HOST}/api/send)
      payload = {}
      timestamp = (Time.now.to_f * 1000).to_i
      platform.downcase!
      if platform == 'android'
        payload = {
          payload: {
            body: {
              ticker: params[:title],
              title: params[:title] || params[:content],
              text: params[:content],
              after_open: 'go_app'
            },
            display_type: 'notification'
          }
        }
        unless custom_keys.empty?
          custom_keys[:debug_timestamp] = Time.now.to_s
          payload[:payload][:body][:after_open] = 'go_custom'
          payload[:payload][:body][:custom] = custom_keys
        end
      elsif platform == 'ios'
        payload = {
          payload: {
            aps: {
              alert: params[:content]
            }
          }
        }
        unless custom_keys.empty?
          custom_keys[:debug_timestamp] = Time.now.to_s
          payload = { payload: payload[:payload].merge(custom_keys) }
        end
      else
        raise %(unknow platform: #{platform})
      end

      push_params = {
        appkey: app_key,
        timestamp: timestamp,
        type: push_type,
        device_tokens: device_tokens
      }.merge(payload)
      puts push_params.to_json

      conn = Faraday.new(url: UMENG_API_HOST) do |faraday|
        faraday.request  :url_encoded
        faraday.adapter  Faraday.default_adapter
      end

      post_body = JSON.dump(push_params)
      sign = md5([UMENG_API_SEND_METHOD, url, post_body, app_master_secret].join)
      response = conn.post do |req|
        req.url 'api/send', sign: sign
        req.headers['Content-Type'] = 'application/json'
        req.body = push_params.to_json
      end
      res = JSON.parse(response.body)
      res['timestamp'] = timestamp
      res
    end

    def md5(something)
      Digest::MD5.hexdigest(something.to_s)
    end
  end
end
