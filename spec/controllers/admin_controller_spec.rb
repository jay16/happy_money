# encoding:utf-8
require File.expand_path '../../spec_helper.rb', __FILE__

describe AdminController do
  it 'GET /admin' do
    get '/admin'
    expect(last_response).to be_ok
  end

  it 'GET /admin/random' do
    get '/admin/random'
    expect(last_response).to be_ok
  end
end
