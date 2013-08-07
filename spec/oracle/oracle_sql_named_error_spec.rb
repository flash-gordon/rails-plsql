require 'spec_helper'

describe Oracle::NamedError do
  after(:each) do
    Object.send(:remove_const, :NoDataFoundError) if defined? NoDataFoundError
    Object.send(:remove_const, :CustomError) if defined? CustomError
  end

  def no_data_found_sql
    <<-SQL
      DECLARE
        l_num NUMBER;
      BEGIN
        SELECT 1
        INTO   l_num
        FROM   DUAL
        WHERE  1 = 0;
      END;
    SQL
  end

  def raise_user_error_sql(code = 20500)
    <<-SQL
      BEGIN
        RAISE_APPLICATION_ERROR(-#{code}, 'Application custom error');
      END;
    SQL
  end

  it 'should allow successor to set Oracle error code' do
    class NoDataFoundError < Oracle::NamedError
      self.error_code = 1403
    end
  end

  it 'should catch errors by class' do
    class NoDataFoundError < Oracle::NamedError
      self.error_code = 1403
    end

    begin
      ActiveRecord::Base.connection.execute(no_data_found_sql)
    rescue NoDataFoundError
      nil # success
    end
  end

  it 'should create class with Oracle error code' do
    Oracle::NamedError.define_exception(:NoDataFoundError, 1403)

    begin
      ActiveRecord::Base.connection.execute(no_data_found_sql)
    rescue NoDataFoundError
      nil # success
    end
  end

  it 'should catch custom application errors' do
    class CustomError < Oracle::NamedError
      self.error_code = 20500
    end

    begin
      ActiveRecord::Base.connection.execute(raise_user_error_sql)
    rescue CustomError
      nil # success
    end
  end

  it 'able to work with array of exception codes' do
    class CustomError < Oracle::NamedError
      self.error_code = [20500, 20501]
    end

    begin
      ActiveRecord::Base.connection.execute(raise_user_error_sql(20500))
      ActiveRecord::Base.connection.execute(raise_user_error_sql(20501))
    rescue CustomError
      nil # success
    end
  end
end