require 'spec_helper'
require 'active_support/log_subscriber/test_helper'


RSpec.configure do |c|
  c.include ActiveSupport::LogSubscriber::TestHelper
end

RSpec.describe 'PLSQL::LogSubscriber' do
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

    expect(logger.logged(:debug).size).to eql(1)
  end

  it 'should not log in info' do
    logger.level = logger_type::INFO
    plsql.nvl(1, 2)

    expect(logger.logged(:debug)).to be_empty
    expect(logger.logged(:info)).to be_empty
  end

  it 'should log errors on procedure calls even in info' do
    logger.level = logger_type::INFO
    plsql.nvl(1) rescue nil
    expect(logger.logged(:error).size).to eql(1)
  end
end
