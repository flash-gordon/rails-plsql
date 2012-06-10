$:.unshift(File.expand_path('../../lib', __FILE__))
$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.setup(:default, :test)
require 'setup_helper'

require 'rspec'
require 'rails-plsql'

CONNECTION_PARAMS = {
  adapter: 'oracle_enhanced',
  database: 'dev4',
  username: 'ais_net',
  password: 'ais_net'
}

ActiveRecord::Base.establish_connection(CONNECTION_PARAMS)
plsql.activerecord_class = ActiveRecord::Base

RSpec.configure do |config|
  # Use color in STDOUT
  config.color_enabled = true
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true
  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate
end