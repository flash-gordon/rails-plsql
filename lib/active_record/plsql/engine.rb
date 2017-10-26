require 'active_record/plsql/pipelined'
require 'active_record/plsql/procedure_methods'
require 'active_record/plsql/base'
require 'active_record/plsql/pipelined_relation'
require 'active_record/plsql/pipelined_scope'
require 'active_record/plsql/pipelined_assoc_relation'
require 'active_record/oracle_enhanced_adapter_patch'
require 'plsql/log_subscriber'

module ActiveRecord::PLSQL
  class Engine < ::Rails::Engine
    initializer 'plsql.logger', after: 'active_record.logger' do
      PLSQL::LogSubscriber.logger = ActiveRecord::Base.logger
    end
  end
end
