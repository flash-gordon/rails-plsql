require 'spec_helper'

describe ActiveRecord::PLSQL::Pipelined do
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

  before(:each) do
    ::User = Class.new(ActiveRecord::PLSQL::Base)
  end

  after(:each) do
    Object.send(:remove_const, :User)
  end

  describe :columns_and_finders do
    it 'should allow to set an Oracle pipelined function as table name' do
      lambda {User.pipelined_function = 'users_pkg.non_exist_function'}.should raise_error(/not found/)
      User.pipelined_function = 'users_pkg.find_users_by_name'
      User.pipelined_function.should be_a PLSQL::PipelinedFunction
      User.table_name.downcase.should == 'users_pkg.find_users_by_name'
    end

    it 'should returns pipelined function arguments' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      User.pipelined_arguments.should be_an Array
      User.pipelined_arguments.first.should be_an ActiveRecord::ConnectionAdapters::OracleEnhancedColumn
      User.pipelined_arguments.map(&:name).should == %w(p_name)

      User.columns.map(&:name).should == %w(id name surname p_name)
    end

    it 'should be able to restore schema cache' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      SetupHelper.clear_schema_cache!
      User.columns.map(&:name).should == %w(id name surname p_name)
    end

    it 'should search users via AR::Relation methods' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.all(conditions: {p_name: 'Albert'}).first
      einstein.surname.should == 'Einstein'
      einstein.should == User.where(p_name: 'Albert').first

      planck = User.where(p_name: 'Max', surname: 'Planck').first
      planck.id.should == 3
    end

    it 'should support dynamic finders' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.where(p_name: 'Albert').first

      einstein.should == User.find_by_p_name('Albert')
      einstein.should == User.find_by_p_name_and_surname('Albert', 'Einstein')
    end

    it 'should be able to use scopes' do
      User.pipelined_function = 'users_pkg.find_users_by_name'

      User.instance_eval do
        scope :einsteins, where(surname: 'Einstein')
        scope :alberts, where(p_name: 'Albert')
      end

      einstein = User.einsteins.where(p_name: 'Albert').first
      einstein.should == User.find_by_p_name('Albert')

      User.alberts.einsteins.first.should == einstein
      User.einsteins.alberts.first.should == einstein
    end

    it 'should store pipelined function arguments at record' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.find_by_p_name('Albert')

      einstein.found_by_arguments.map(&:first).should == User.pipelined_arguments
      einstein.found_by_arguments.first[1].should == 'Albert'
    end

    it 'should reload objects' do
      User.pipelined_function = 'users_pkg.find_users_by_name'
      einstein = User.find_by_p_name('Albert')

      einstein.clone.reload.should == einstein
    end

    it 'should use where with strings' do
      User.pipelined_function = 'users_pkg.find_users_by_name'

      rutherford = User.where(p_name: 'Ernest').where("surname = 'Rutherford'").to_a
      pending 'todo'
      rutherford.map(&:surname).uniq.should == %w(Rutherford)
    end
  end

  describe :associations do
    before(:each) do
      ::Post = Class.new(ActiveRecord::PLSQL::Base)
      User.pipelined_function = 'users_pkg.find_users_by_name'
      Post.pipelined_function = 'users_pkg.find_posts_by_user_id'
      User.has_many :posts, foreign_key: 'p_user_id', inverse_of: :user
      User.has_many :posts_in_1905, class_name: 'Post', foreign_key: 'p_user_id', inverse_of: :user, conditions: 'year = 1905'
      Post.belongs_to :user, foreign_key: 'user_id', inverse_of: :posts

      Post.scope :in_the_year_1905, Post.where(year: 1905)
    end

    after(:each) do
      Object.send(:remove_const, :Post)
    end

    let(:einstein) {User.find_by_p_name('Albert')}

    it 'should support associations' do
      'On the Electrodynamics of Moving Bodies'.should be_in einstein.posts.map(&:title)
    end

    it 'should support associations with scopes' do
      einstein.posts.in_the_year_1905.map(&:year).uniq.should == [1905]
    end

    it 'should support associations with conditions' do
      pending 'todo'
      einstein.posts_in_1905.map(&:year).uniq.should == [1905]
    end

    it 'should support associations and scopes merging' do
      special_relativity = einstein.posts.in_the_year_1905.where(title: 'On the Electrodynamics of Moving Bodies').first
      special_relativity.description.should == 'Special relativity origins'
    end

    it 'should work with associations with two wheres' do
      first_post = einstein.posts.where(description: 'Special relativity origins').first
      first_post.title.should == 'On the Electrodynamics of Moving Bodies'
    end

    it 'should set reverse links for bound model' do
      # Doesn't work without to_a. See https://github.com/rails/rails/issues/5717
      first_post = einstein.posts.to_a.first
      first_post.user.should == einstein
    end
  end
end