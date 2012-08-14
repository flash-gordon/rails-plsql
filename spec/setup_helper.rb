module SetupHelper
  extend self

  def create_package(package)
    header = File.open(File.join(package_headers_path, '%s.sql' % package)).read
    body = File.open(File.join(package_bodies_path, '%s.sql' % package)).read
    conn.execute(header)
    conn.execute(body)
  end

  def create_user_table
    conn.create_table(:users) do |t|
      t.integer :id, primary_key: true
      t.string  :name
      t.string  :surname
    end
  end

  def create_post_table
    conn.create_table(:posts) do |t|
      t.integer :id, primary_key: true
      t.integer :user_id
      t.string  :title
      t.string  :description
      t.integer :year
    end
  end

  def seed(table_name)
    table_name = table_name.to_s
    file_path = File.join(fixtures_path, table_name + '.yml')
    data = YAML.load(File.open(file_path, 'r').read)[table_name]
    seed_table(table_name, data)
  end

  def drop_table(table_name)
    conn.drop_table(table_name) rescue nil
  end

  def drop_package(package)
    conn.execute('DROP PACKAGE %s' % package) rescue nil
  end

  def clear_schema_cache!
    conn.schema_cache.clear!
  end

  def conn
    @conn ||= ActiveRecord::Base.connection
  end

  private

    def fixtures_path
      @fixtures_path ||= File.join(File.dirname(__FILE__), 'fixtures')
    end

    def plsql_scripts_path
      @plsql_scripts_path ||= File.join(fixtures_path, 'plsql')
    end

    def package_headers_path
      @package_headers_path ||= File.join(File.join(plsql_scripts_path, 'packages'), 'headers')
    end

    def package_bodies_path
      @package_bodies_path ||= File.join(File.join(plsql_scripts_path, 'packages'), 'bodies')
    end

    def seed_table(table, data)
      columns = Hash[conn.columns(table).map {|c| [c.name, c]}]
      data.each {|row| insert_row(table, columns, row)}
      conn.commit_db_transaction
    end

    def insert_row(table, columns, data)
      insert_sql = <<-SQL
        INSERT INTO #{table}(#{data.keys.join(', ')})
        VALUES(#{data.keys.map{|s| ':' + s}.join(', ')})
      SQL
      binds = data.map {|a| [columns[a[0]], a[1]]}

      conn.exec_insert(insert_sql, 'INSERT', binds)
    end
end