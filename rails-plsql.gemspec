# Provide a simple gemspec so you can easily use your
# project in your rails apps through git.
Gem::Specification.new do |s|
  s.name = 'rails-plsql'
  s.version = '0.3.0'
  s.authors = ['Nikita Shilnikov']
  s.email = %w(fg@flashgordon.ru)
  s.homepage = 'https://github.com/flash-gordon/rails-plsql'

  s.summary = 'Extension for ActiveRecord that provides convenient using some of Oracle PL/SQL features.'
  s.description = 'rails-plsql adds functional that allows to use some special Oracle Database features in standard ActiveRecord models.'
  s.files = Dir['lib/**/*'] + %w(MIT-LICENSE README.md)

  s.add_dependency('ruby-plsql', ['~> 0.6.0'])
  s.add_dependency('activerecord', ['~> 5.1.0'])
  s.add_dependency('activerecord-oracle_enhanced-adapter', ['~> 1.8.2'])

  s.require_paths = %w(lib)
end
