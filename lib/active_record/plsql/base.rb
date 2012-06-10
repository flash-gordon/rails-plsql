module ActiveRecord::PLSQL
  class Base < ActiveRecord::Base
    self.abstract_class = true
    include Pipelined
    include ProcedureMethods
  end
end