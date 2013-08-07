rails-plsql
====================================

Middleware between ActiveRecord and Oracle Database

Description
-----------

This gem is ActiveRecord extension for some Oracle Database specific features such as pipelined functions or PL/SQL procedures. It uses [ruby-plsql](https://github.com/rsim/ruby-plsql) and [oracle enhanced adapter](https://github.com/rsim/oracle-enhanced) gems as dependencies for connection to Oracle and calling PL/SQL procedures and functions. It also adds basic logger to [my fork](https://github.com/flash-gordon/ruby-plsql) of ruby-plsql gem.

Installation
------------

### Rails 3.2

Just put this line into your Gemfile

    gem 'rails-plsql', '~> 0.1'

Gem tested with MRI 1.9.2, 1.9.3, 2.0.0 and JRuby 1.7.4. So if you use ruby-oci8 then add also

    gem 'ruby-oci8', '~> 2.1.0'

And run

    bundle install

to install all gems.

Other versions of Rails not tested.

Usage
-----

### Pipelined functions as tables in ActiveRecord models

Oracle pipelined functions could be used as data source instead of ordinary tables (or views).

If you have such PL/SQL function

```sql

CREATE OR REPLACE
PACKAGE users_pkg IS

  TYPE users_list IS TABLE OF USERS%ROWTYPE;

  FUNCTION find_users_by_name(
    p_name    USERS.NAME%TYPE)
  RETURN users_list
  PIPELINED;

END users_pkg;
/

CREATE OR REPLACE
PACKAGE BODY users_pkg IS

  FUNCTION find_users_by_name(
    p_name    USERS.NAME%TYPE)
  RETURN users_list
  PIPELINED
  IS
  BEGIN
    FOR l_user IN (
      SELECT *
      FROM   users
      WHERE  name = p_name)
    LOOP
      PIPE ROW(l_user);
    END LOOP;
  END FIND_USERS_BY_NAME;

END users_pkg;
/
```

So you can set this function in your model instead of table name

```ruby
class User < ActiveRecord::Base
  include ActiveRecord::PLSQL::Pipelined

  self.pipelined_function = 'users_pkg.find_users_by_name'

  scope :alberts, where(p_name: 'Albert')
  scope :einsteins, where(surname: 'Einstein')
end
```

and use standard Rails scopes and finders

```ruby
User.alberts
# [#<User id: #<BigDecimal:6fec77a4,'0.1E1',9(36)>, name: "Albert", surname: "Einstein">]
User.alberts.einsteins.first
# #<User id: #<BigDecimal:6fec77a4,'0.1E1',9(36)>, name: "Albert", surname: "Einstein">

User.all(conditions: {p_name: 'Max'})
# [#<User id: #<BigDecimal:6ee2c728,'0.3E1',9(36)>, name: "Max", surname: "Planck">]
```

Pipelined function arguments must be set via `where` condition (see `p_name` usage above). If not they will be set to NULL.

### Oracle procedures and functions as methods of ActiveRecord objects

If you have some PL/SQL package related with AR model you could bind it to class.

```sql
CREATE OR REPLACE
PACKAGE users_pkg IS

  FUNCTION salute(
    p_name    IN VARCHAR2)
  RETURN VARCHAR2;

END users_pkg;
/

CREATE OR REPLACE
PACKAGE BODY users_pkg IS

  FUNCTION salute(
    p_name    IN VARCHAR2)
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN 'Hello, ' || p_name || '!';
  END salute;

END users_pkg;
/
```

```ruby
class User < ActiveRecord::Base
  include ActiveRecord::PLSQL::ProcedureMethods

  self.plsql_package = plsql.users_pkg
  procedure_method :salute
end
```

After that you can call procedure as method

```ruby
einstein = User.find_by_name('Albert')
# Just pass arguments as array or hash
einstein.salute(p_name: einstein.name)  # 'Hello, Albert!'
einstein.salute([einstein.surname])     # 'Hello, Einstein!'
```

Support
-------

Feel free to contact me at fg@flashgordon.ru or send a pull request.