require 'spec_helper'

describe 'ProcedureMethods' do
  before(:all) do
    SetupHelper.create_user_table
    SetupHelper.create_post_table
    SetupHelper.seed(:users)

    SetupHelper.create_package(:users_pkg)
  end

  after(:all) do
    SetupHelper.drop_package(:users_pkg)
    SetupHelper.drop_table(:posts)
    SetupHelper.drop_table(:users)
  end

  before do
    ::User = Class.new(ActiveRecord::PLSQL::Base)
    SetupHelper.clear_schema_cache!
    PLSQL::LogSubscriber.logger = ActiveSupport::BufferedLogger.new($stdout)
    PLSQL::LogSubscriber.logger.level = ActiveSupport::BufferedLogger::ERROR
  end

  after { Object.send(:remove_const, :User) }

  describe :saving_via_procedures do
    let(:create_procedure) {plsql.users_pkg['create_user']}
    let(:update_procedure) {plsql.users_pkg['update_user']}
    let(:bohr) {User.find_by_surname('Bohr')}
    let(:einstein) {User.find_by_name('Albert')}

    it 'should allow to set save procedure' do
      User.set_create_procedure(create_procedure)
      User.set_update_procedure(update_procedure)

      User.procedure_methods[:create][:procedure].should == create_procedure
      User.procedure_methods[:update][:procedure].should == update_procedure
    end

    it 'should update records via procedure' do
      User.set_update_procedure(update_procedure, arguments: proc { {p_id: id, p_name: name, p_surname: surname} })

      bohr.name = 'AAGE'
      bohr.save
      bohr.name.should == 'Aage'
    end

    it 'should create records via procedure' do
      User.set_create_procedure(create_procedure, arguments: proc { {p_name: name, p_surname: surname} })

      bohr = User.new
      bohr.name = 'AAGE'
      bohr.surname = 'BOHR'
      bohr.save

      bohr.id.should_not be_nil
      bohr.name.should == 'Aage'
      bohr.surname.should == 'Bohr'
    end

    it 'should run create and update callbacks' do
      cnt = 0

      User.set_create_procedure(create_procedure, arguments: proc { {p_name: name, p_surname: surname} })
      User.after_create { cnt += 1 }
      User.create(name: 'AAGE', surname: 'BOHR')
      cnt.should == 1
    end

    it 'should call procedures as methods' do
      User.plsql_package = plsql.users_pkg
      User.procedure_method(:salute)

      einstein.salute([einstein.name]).should == 'Hello, Albert!'
    end

    it 'should inherit methods from base class' do
      User.plsql_package = plsql.users_pkg
      User.procedure_method(:salute)
      descendant_class = Class.new(User)

      einstein = descendant_class.find_by_name('Albert')
      einstein.salute([einstein.name]).should == 'Hello, Albert!'
    end

    it 'supports super call' do
      User.plsql_package = plsql.users_pkg
      User.procedure_method(:salute)

      called_with_super = false

      User.class_eval do
        define_method(:salute) do |*args|
          called_with_super = true
          super(*args)
        end
      end

      bohr.salute([bohr.name])

      expect(called_with_super).to be true
    end
  end
end