use v6;

unit module Sparky:ver<0.0.25>;
use YAMLish;
use DBIish;
use Time::Crontab;

my $root = %*ENV<SPARKY_ROOT> || %*ENV<HOME> ~ '/.sparky/projects';

sub get-sparky-conf is export {

  my $conf-file = ( %*ENV<USER> && %*ENV<USER> =! 'root' ) ?? %*ENV<HOME> ~ '/sparky.yaml' !! ( '/root/sparky.yaml' );

  my %conf = $conf-file.IO ~~ :e ?? load-yaml(slurp $conf-file) !! Hash.new;

}

multi sub get-dbh ( $dir ) is export {

  my %conf = get-sparky-conf();

  my $dbh;

  if %conf<database> && %conf<database><engine> && %conf<database><engine> !~~ / :i sqlite / {

    $dbh  = DBIish.connect(
        %conf<database><engine>,
        host      => %conf<database><host>,
        port      => %conf<database><port>,
        database  => %conf<database><name>,
        user      => %conf<database><user>,
        password  => %conf<database><pass>,
    );

    say "load {%conf<database><engine>} dbh";

  } else {

    $dbh  = DBIish.connect("SQLite", database => "$dir/../db.sqlite3".IO.absolute  );

    say "load sqlite dbh for: " ~ ("$dir/../db.sqlite3".IO.absolute);

  }

  $dbh

}


multi sub get-dbh {

  my %conf = get-sparky-conf();

  my $dbh;

  if %conf<database> && %conf<database><engine> && %conf<database><engine> !~~ / :i sqlite / {

    $dbh  = DBIish.connect(
        %conf<database><engine>,
        host      => %conf<database><host>,
        port      => %conf<database><port>,
        database  => %conf<database><name>,
        user      => %conf<database><user>,
        password  => %conf<database><pass>,
    );

  } else {

    my $db-name = "$root/db.sqlite3";
    $dbh  = DBIish.connect("SQLite", database => $db-name );

  }

}

sub build-is-running ( $dir ) {

  my $project = $dir.IO.basename;

  my @proc-check-cmd = ("bash", "-c", "ps aux | grep sparky-runner.pl6 | grep '\\--marker=$project ' | grep -v grep");

  my $proc-run = run @proc-check-cmd, :out;

  if $proc-run.exitcode == 0 {

      $proc-run.out.get ~~ m/(\d+)/;

      my $pid = $0;

      say "{DateTime.now} --- [$project] build already running, pid: $pid SKIP ... ";

      return True

  } else {

    return False
  }

}

sub schedule-build ( $dir, %opts? ) is export {

  my $project = $dir.IO.basename;

  my %config = Hash.new;

  if "$dir/sparky.yaml".IO ~~ :f {

    %config = load-yaml(slurp "$dir/sparky.yaml");

  }

  if %config<disabled>  {
    say "{DateTime.now} --- [$project] build is disabled, SKIP ... ";
    return;
  }

  if %config<is_downstream> {
    say "{DateTime.now} --- [$project] is downstream, SKIP when running directly ... ";
    return;
  }

  # check if build is triggered by file triggers
  my $trigger-file;
  my $run-by-trigger = False;

  if "{$dir}/.triggers/".IO ~~ :d {

    for dir("{$dir}/.triggers/", test => /:i '.' trg $/ ) -> $file {
      $run-by-trigger = True;
      $trigger-file = "{$file}.conf".IO.absolute;
      last;
    }
  }

  if $run-by-trigger {

      say "{DateTime.now} --- [$project] build trigerred by file trigger <$trigger-file> ...";

      if ! build-is-running($dir) {

        move $trigger-file, "{$trigger-file}.conf";

        Proc::Async.new(
          'sparky-runner.pl6',
          "--marker=$project",
          "--dir=$dir",
          "--sparrowdo-conf={$trigger-file}.conf",
          "--make-report"
        ).start;

     }
  
  } else {

    if %config<crontab> and ! %*ENV<SPARKY_SKIP_CRON> and ! %opts<skip-cron> {
      my $crontab = %config<crontab>;
      my $tc = Time::Crontab.new(:$crontab);
      if $tc.match(DateTime.now, :truncate(True)) {
        say "{DateTime.now} --- [$project] build triggered by cron trigger: <$crontab> ...";
        Proc::Async.new(
          'sparky-runner.pl6',
          "--marker=$project",
          "--dir=$dir",
          "--make-report"
        ).start if ! build-is-running($dir);
      } else {
        say "{DateTime.now} --- [$project] build is skipped by cron: $crontab ... ";
        return;
      }
    } elsif !%config<crontab>  {
        say "{DateTime.now} --- [$project] crontab entry not found, consider manual start or set up cron later, SKIP ... ";
        return;
    }
  
  
  

  }

}

