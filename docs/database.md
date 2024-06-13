# Databases

Sparky keeps it's data in database, by default it uses sqlite,
following databases are supported:

* SQLite
* MySQL/MariaDB
* PostgreSQL

## Configuring database

Following is an example for MySQL database, the same rules are applied for other database,
like PostgreSQL, etc.

### Create Sparky configuration file

You should defined database engine and connection parameters, say we want to use MySQL:

```bash
$ nano ~/sparky.yaml
```

With content:

```yaml
database:
  engine: mysql
  host: $dbhost
  port: $dbport
  name: $dbname
  user: $dbuser
  pass: $dbpassword
```

For example:

```yaml
database:
  engine: mysql
  host: "127.0.0.1"
  port: 3306
  name: sparky
  user: sparky
  pass: "123"
```

### Installs dependencies

Depending on platform it should be client needed for your database API, for example for Debian we have to:

```bash
$ sudo yum install mysql-client
```

### Creating database user, password and schema

DB init script will generate database schema, provided that user defined and sparky configuration file has access to
the database:

```bash
$ raku db-init.raku
```

That is it, now Sparky runs under MySQL!

