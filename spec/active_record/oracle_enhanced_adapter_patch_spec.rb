require 'spec_helper'

describe ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter do
  let(:function) {'users_pkg.find_users_by_name'}
  subject(:conn) {SetupHelper.conn}

  before(:all) do
    SetupHelper.create_user_table
    SetupHelper.create_post_table
    SetupHelper.create_package(:users_pkg)
  end

  after(:all) do
    SetupHelper.drop_package(:users_pkg)
    SetupHelper.drop_table(:users)
    SetupHelper.drop_table(:posts)
  end

  before {SetupHelper.clear_schema_cache!}

  it 'should return list of columns and arguments for pipelined function' do
    lambda {conn.columns(function)}.should_not raise_error
    conn.columns(function).map(&:name).should == %w(id name surname country p_name)
  end
end

