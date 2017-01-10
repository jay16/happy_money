# encoding:utf-8
require File.expand_path '../../spec_helper.rb', __FILE__

describe MembersController do
  it 'GET /members' do
    get '/members'
    expect(last_response).to be_ok
  end

  it 'GET /members/rspec' do
    get '/members/rspec'
    expect(last_response).to be_ok
  end
end
