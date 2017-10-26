RSpec.describe ActiveRecord::PLSQL::Pipelined do
  before(:all) do
    SetupHelper.create_user_table
    SetupHelper.seed(:users)

    SetupHelper.create_post_table
    SetupHelper.seed(:posts)

    SetupHelper.create_package(:users_pkg)
  end

  after(:all) do
    SetupHelper.drop_package(:users_pkg)
    SetupHelper.drop_table(:posts)
    SetupHelper.drop_table(:users)
  end

  before do
    SetupHelper.clear_schema_cache!
    ::User = Class.new(ActiveRecord::PLSQL::Base)
  end

  after { Object.send(:remove_const, :User) }

  describe :columns_and_finders do
    it 'should allow to set an Oracle pipelined function as table name' do
      expect {
        User.pipelined_function = 'users_pkg.non_exist_function'
      }.to raise_error(/not found/)
      User.pipelined_function = 'users_pkg.find_users_by_name'
      expect(User.pipelined_function).to be_a PLSQL::PipelinedFunction
      expect(User.table_name.downcase).to eql('users_pkg.find_users_by_name')
    end

    it 'should returns pipelined function arguments' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      expect(User.pipelined_arguments).to be_an Array
      expect(User.pipelined_arguments.first).to be_an ActiveRecord::ConnectionAdapters::OracleEnhancedColumn
      expect(User.pipelined_arguments.map(&:name)).to eql(%w(p_name))

      expect(User.columns.map(&:name)).to eql(%w(id name surname country p_name))
    end

    it 'should be able to restore schema cache' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      SetupHelper.clear_schema_cache!
      expect(User.columns.map(&:name)).to eql(%w(id name surname country p_name))
    end

    it 'should search users via AR::Relation methods' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.where(p_name: 'Albert').first
      expect(einstein.surname).to eql('Einstein')
      expect(einstein).to eq(User.where(p_name: 'Albert').first)

      planck = User.where(p_name: 'Max', surname: 'Planck').first
      expect(planck).to eq(User.where(p_name: 'Max', surname: 'Planck').first)
      expect(planck.id).to eql(3)
    end

    it 'should support dynamic finders' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.where(p_name: 'Albert').first

      expect(einstein).to eq(User.find_by_p_name('Albert'))
      expect(einstein).to eq(User.find_by_p_name_and_surname('Albert', 'Einstein'))
    end

    it 'should be able to use scopes' do
      User.pipelined_function = 'users_pkg.find_users_by_name'

      User.instance_eval do
        scope :einsteins, -> { where(surname: 'Einstein') }
        scope :alberts, -> { where(p_name: 'Albert') }
      end

      einstein = User.einsteins.where(p_name: 'Albert').first
      expect(einstein).to eq(User.find_by_p_name('Albert'))

      expect(User.alberts.einsteins.first).to eq(einstein)
      expect(User.einsteins.alberts.first).to eq(einstein)
    end

    it 'should store pipelined function arguments at record' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.find_by_p_name('Albert')

      expect(einstein.found_by_arguments[0].value).to eql('Albert')
    end

    it 'should reload objects' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.find_by_p_name('Albert')

      expect(einstein.clone.reload).to eq(einstein)
    end

    it 'should use where with strings' do
      User.pipelined_function = 'users_pkg.find_users_by_name'

      rutherford = User.where(p_name: 'Ernest').where("surname = 'Rutherford'").to_a
      expect(rutherford.map(&:surname).uniq).to eql(%w(Rutherford))
    end
  end

  describe :associations do
    before(:each) do
      ::Post = Class.new(ActiveRecord::PLSQL::Base)
      User.pipelined_function = 'users_pkg.find_users_by_name'
      Post.pipelined_function = 'users_pkg.find_posts_by_user_id'
      User.has_many :posts, foreign_key: 'p_user_id', inverse_of: :user
      Post.belongs_to :user, foreign_key: 'user_id', inverse_of: :posts

      Post.scope :in_the_year_1905, -> { where(year: 1905) }
    end

    after(:each) do
      Object.send(:remove_const, :Post)
    end

    let(:einstein) { User.find_by_p_name('Albert') }
    let(:planck) { User.find_by_p_name('Max') }

    it 'should support associations' do
      expect('On the Electrodynamics of Moving Bodies').to be_in einstein.posts.map(&:title)
    end

    fit 'should support associations with scopes' do
      expect(einstein.posts.in_the_year_1905.map(&:year).uniq).to eql([1905])
    end

    it 'should support associations and scopes merging' do
      special_relativity = einstein.posts.in_the_year_1905.where(title: 'On the Electrodynamics of Moving Bodies').first
      expect(special_relativity.description).to eql('Special relativity origins')
    end

    it 'should work with associations with two wheres' do
      first_post = einstein.posts.where(description: 'Special relativity origins').first
      expect(first_post.title).to eql('On the Electrodynamics of Moving Bodies')
    end

    it 'should set reverse links for bound model' do
      pending
      # Doesn't work without to_a. See https://github.com/rails/rails/issues/5717
      first_post = einstein.posts.to_a.first
      expect(first_post.user).to eq(einstein)
    end

    it 'should work with shared scope' do
      User.instance_eval do
        # create shared scope
        scope :german, -> { where(country: 'Germany') }
      end

      expect(User.german.where(p_name: 'Albert').first.name).to eql('Albert')
      expect(User.german.where(p_name: 'Max').first.name).to eql('Max')
    end
  end
end
