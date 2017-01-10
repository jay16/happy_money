# encoding:utf-8
require File.expand_path '../../spec_helper.rb', __FILE__

describe HomeController do
  it 'GET /' do
    get '/'
    expect(last_response).to be_ok
  end
end
