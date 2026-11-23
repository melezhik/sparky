use v6;
use Data::Dump;
use Sparky;
use Sparky::Sqlite;

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

$db-name = "$root/db.sqlite3";
$dbh  = DB.open($db-name,False,True);
LEAVE { .close with $db };

$dbh.execute(q:to/STATEMENT/);
  DROP TABLE IF EXISTS builds
STATEMENT

$dbh.execute(q:to/STATEMENT/);
  CREATE TABLE builds (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    project     varchar(255),
    job_id      varchar(255),
    description TEXT,
    state       int,
    dt datetime default current_timestamp
  )
STATEMENT

say "$engine db populated as $db-name";


}
