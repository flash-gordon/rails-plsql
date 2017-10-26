RSpec.describe 'ProcedureMethods' do
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
    PLSQL::LogSubscriber.logger = ActiveSupport::Logger.new($stdout)
    PLSQL::LogSubscriber.logger.level = ActiveSupport::Logger::ERROR
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

      expect(User.procedure_methods[:create][:procedure]).to eql(create_procedure)
      expect(User.procedure_methods[:update][:procedure]).to eql(update_procedure)
    end

    it 'should update records via procedure' do
      User.set_update_procedure(update_procedure, arguments: proc { {p_id: id, p_name: name, p_surname: surname} })

      bohr.name = 'AAGE'
      bohr.save
      expect(bohr.name).to eql('Aage')
    end

    it 'should create records via procedure' do
      User.set_create_procedure(create_procedure, arguments: proc { {p_name: name, p_surname: surname} })

      bohr = User.new
      bohr.name = 'AAGE'
      bohr.surname = 'BOHR'
      bohr.save

      expect(bohr.id).not_to be_nil
      expect(bohr.name).to eql('Aage')
      expect(bohr.surname).to eql('Bohr')
    end

    it 'should run create and update callbacks' do
      cnt = 0

      User.set_create_procedure(create_procedure, arguments: proc { {p_name: name, p_surname: surname} })
      User.after_create { cnt += 1 }
      User.create(name: 'AAGE', surname: 'BOHR')
      expect(cnt).to eql(1)
    end

    it 'should call procedures as methods' do
      User.plsql_package = plsql.users_pkg
      User.procedure_method(:salute)

      expect(einstein.salute([einstein.name])).to eql('Hello, Albert!')
    end

    it 'should inherit methods from base class' do
      User.plsql_package = plsql.users_pkg
      User.procedure_method(:salute)
      descendant_class = Class.new(User)

      einstein = descendant_class.find_by_name('Albert')
      expect(einstein.salute([einstein.name])).to eql('Hello, Albert!')
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
