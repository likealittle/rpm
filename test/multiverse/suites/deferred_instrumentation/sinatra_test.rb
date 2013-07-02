# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'sinatra', 'sinatra_test_cases'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'agent_helper'))

require 'newrelic_rpm'
require 'sinatra'

class DeferredSinatraTestApp < Sinatra::Base
  include NewRelic::Agent::Instrumentation::Rack

  configure do
    # display exceptions so we see what's going on
    disable :show_exceptions

    # create a condition (sintra's version of a before_filter) that returns the
    # value that was passed into it.
    set :my_condition do |boolean|
      condition do
        halt 404 unless boolean
      end
    end
  end

  get '/user/login' do
    "please log in"
  end

  # this action will always return 404 because of the condition.
  get '/user/:id', :my_condition => false do |id|
    "Welcome #{id}"
  end

  get '/raise' do
    raise "Uh-oh"
  end

  # check that pass works properly
  condition { pass { halt 418, "I'm a teapot." } }
  get('/pass') { }

  get '/pass' do
    "I'm not a teapot."
  end

  class Error < StandardError; end
  error(Error) { halt 200, 'nothing happened' }
  condition { raise Error }
  get('/error') { }

  condition do
    raise "Boo" if $precondition_already_checked
    $precondition_already_checked = true
  end
  get('/precondition') { 'precondition only happened once' }

  get '/route/:name' do |name|
    # usually this would be a db test or something
    pass if name != 'match'
    'first route'
  end

  get '/route/no_match' do
    'second route'
  end

  before '/filtered' do
    @filtered = true
  end

  get '/filtered' do
    @filtered ? 'got filtered' : 'nope'
  end

  get /\/regex.*/ do
    "Yeah, regex's!"
  end
end

class DeferredSinatraTest < Test::Unit::TestCase
  include SinatraTestCases

  def app
    Rack::Builder.new( DeferredSinatraTestApp ).to_app
  end


  def test_ignores_route_metrics
    # Can't use 'newrelic_ignore' if newrelic was loaded before sinatra, as the
    # instrumentation doesn't load until Rack is building the app to run it.
  end
end
