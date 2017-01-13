# encoding: utf-8
module Admin
  # 登录用户视图方法集
  module ApplicationHelper
    # 不同层级的页面，路径设置不同
    def render_page_header
      haml :'../layouts/_admin_header'
    end
  end
end
