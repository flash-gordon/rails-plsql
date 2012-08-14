require 'spec_helper'

describe OCI8::OCINamedError do
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

  def raise_user_error_sql
    <<-SQL
      BEGIN
        RAISE_APPLICATION_ERROR(-20500, 'Application custom error');
      END;
    SQL
  end

  it 'should allow successor to set Oracle error code' do
    class NoDataFoundError < OCI8::OCINamedError
      self.oci_error_code = 1403
    end
  end

  it 'should catch errors by class' do
    class NoDataFoundError < OCI8::OCINamedError
      self.oci_error_code = 1403
    end

    begin
      cursor = ActiveRecord::Base.connection.raw_connection.parse(no_data_found_sql)
      cursor.exec
    rescue NoDataFoundError
      nil # success
    ensure
      cursor.close
    end
  end

  it 'should create class with Oracle error code' do
    OCI8::OCINamedError.define_exception(:NoDataFoundError, 1403)

    begin
      cursor = ActiveRecord::Base.connection.raw_connection.parse(no_data_found_sql)
      cursor.exec
    rescue NoDataFoundError
      nil # success
    ensure
      cursor.close
    end
  end

  it 'should catch custom application errors' do
    class CustomError < OCI8::OCINamedError
      self.oci_error_code = 20500
    end

    begin
      cursor = ActiveRecord::Base.connection.raw_connection.parse(raise_user_error_sql)
      cursor.exec
    rescue CustomError
      nil # success
    ensure
      cursor.close
    end
  end
end