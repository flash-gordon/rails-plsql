$:.unshift(File.expand_path('../../lib', __FILE__))
$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.setup(:default, :test)
require 'setup_helper'

require 'rspec'
require 'rails-plsql'
require 'pry'
require 'rails'

begin
  require 'pry-byebug'
rescue LoadError
end

CONNECTION_PARAMS = {
  adapter: 'oracle_enhanced',
  database: ENV['RAILS_PLSQL_DB'],
  username: ENV['RAILS_PLSQL_USERNAME'],
  password: ENV['RAILS_PLSQL_PASSWORD']
}

ActiveRecord::Base.establish_connection(CONNECTION_PARAMS)
plsql.activerecord_class = ActiveRecord::Base

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true
  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate

  config.disable_monkey_patching!
end
