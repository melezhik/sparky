use v6;
use DBIish;
use Data::Dump;
use Sparky;

sub MAIN (
  Str  :$root = %*ENV<HOME> ~ '/.sparky/projects',
)

{

mkdir $root;

my %conf = get-sparky-conf();

my $dbh;
my $engine;
my $db-name;

say "config: " ~ Dump(%conf);

if %conf<database> && %conf<database><engine> && %conf<database><engine> !~~ / :i sqlite / {
  $engine = %conf<database><engine>;
  $db-name = %conf<database><name>;
  $dbh  = DBIish.connect( 
      $engine,
      host      => %conf<database><host>, 
      port      => %conf<database><port>, 
      database  => %conf<database><name>, 
      user      => %conf<database><user>, 
      password  => %conf<database><pass>, 
  );

} else {

  $engine = 'SQLite';
  $db-name = "$root/db.sqlite3";
  $dbh  = DBIish.connect("SQLite", database => $db-name );

}

$dbh.do(q:to/STATEMENT/);
    DROP TABLE IF EXISTS builds
    STATEMENT

if $engine ~~ /:i sqlite/ {

  $dbh.do(q:to/STATEMENT/);
      CREATE TABLE builds (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          project     varchar(255),
          job_id      varchar(255),
          description TEXT,
          state       int,
          dt datetime default current_timestamp
      )
      STATEMENT

} elsif $engine ~~ /:i mysql/ {

  $dbh.do(q:to/STATEMENT/);
      CREATE TABLE builds (
          id          int primary key auto_increment,
          project     varchar(255),
          job_id      varchar(255),
          description varchar(255),
          state       int,
          dt timestamp default CURRENT_TIMESTAMP
      ) CHARACTER SET utf8
      STATEMENT

} elsif $engine ~~ /:i pg/ {

  $dbh.do(q:to/STATEMENT/);
      CREATE TABLE builds (
          id          SERIAL PRIMARY KEY,
          project     varchar(255),
          job_id      varchar(255),
          description varchar(255),
          state       int,
          dt timestamp default CURRENT_TIMESTAMP
      )
      STATEMENT

}

say "$engine db populated as $db-name";

$dbh.dispose;

}



