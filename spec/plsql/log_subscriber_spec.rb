require 'spec_helper'
require 'active_support/log_subscriber/test_helper'


RSpec.configure do |c|
  c.include ActiveSupport::LogSubscriber::TestHelper
end

describe 'PLSQL::LogSubscriber' do
  let(:logger_type) {ActiveSupport::LogSubscriber::TestHelper::MockLogger}
  let(:logger) {PLSQL::LogSubscriber.logger}

  before(:each) do
    ::User = Class.new(ActiveRecord::PLSQL::Base)
    PLSQL::LogSubscriber.logger = logger_type.new
  end

  after(:each) do
    Object.send(:remove_const, :User)
    PLSQL::LogSubscriber.logger = nil
  end

  it 'should log in debug' do
    plsql.nvl(1, 2)

    logger.logged(:debug).size.should == 1
  end

  it 'should not log in info' do
    logger.level = logger_type::INFO
    plsql.nvl(1, 2)

    logger.logged(:debug).should be_empty
    logger.logged(:info).should be_empty
  end

  it 'should log errors on procedure calls even in info' do
    logger.level = logger_type::INFO
    plsql.nvl(1) rescue nil
    logger.logged(:error).size.should == 1
  end
end