use v6;

unit module Sparky:ver<0.0.30>;
use YAMLish;
use DBIish;
use Time::Crontab;

my $root = %*ENV<SPARKY_ROOT> || %*ENV<HOME> ~ '/.sparky/projects';

sub get-sparky-conf is export {

  my $conf-file = %*ENV<HOME> ~ '/sparky.yaml';

  my %conf = $conf-file.IO ~~ :f ?? load-yaml($conf-file.IO.slurp) !! Hash.new;

  %conf;

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

    #say "load {%conf<database><engine>} dbh";

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

  my @proc-check-cmd = ("bash", "-c", "ps aux | grep sparky-runner.raku | grep '\\--marker=$project ' | grep -v grep");

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

  # check  triggered jobs

  my $trigger-file;
  my $run-by-trigger = False;

  if "{$dir}/.triggers/".IO ~~ :d {
    for dir("{$dir}/.triggers/") -> $file {
      $run-by-trigger = True;
      $trigger-file = $file.IO.absolute;
      last;
    }
  }

  if $run-by-trigger {

      say "{DateTime.now} --- [$project] build trigerred by file trigger <$trigger-file> ...";

      if ! build-is-running($dir) {

        Proc::Async.new(
          'sparky-runner.raku',
          "--marker=$project",
          "--dir=$dir",
          "--trigger=$trigger-file",
          "--make-report"
        ).start;

     }

  }

  # check cron jobs

  if %config<crontab> and ! %*ENV<SPARKY_SKIP_CRON> and ! %opts<skip-cron> {

    my $crontab = %config<crontab>;

    my $tc = Time::Crontab.new(:$crontab);

    if $tc.match(DateTime.now, :truncate(True)) {

      my $cron-lock-file =   "{$dir}/../../work/{$project}/.lock/cron";

      if $cron-lock-file.IO ~~ :f && ( now - "{$cron-lock-file}".IO.modified ).Int < 60 {
         say "{DateTime.now} --- [$project] cron lock file exists with an age less then 60 secs,  SKIP ...";
         next;
      }

      say "{DateTime.now} --- [$project] build queued by cron trigger: <$crontab> ...";

      mkdir "{$dir}/../../work/{$project}/.lock/" unless "{$dir}/../../work/{$project}/.lock/".IO ~~ :d;

      $cron-lock-file.IO.spurt("");

      my $id = "{('a' .. 'z').pick(20).join('')}{$*PID}";

      mkdir "$dir/.triggers";

      spurt "$dir/.triggers/$id", "%(
        description => 'triggered by cron'
      )";

    } else {
      say "{DateTime.now} --- [$project] build is skipped by cron: $crontab ... ";
      return;
    }

  } elsif %config<scm> {

    my $scm-url = %config<scm><url>;

    my $scm-branch = %config<scm><branch> || 'master';

    my $scm-dir =   "{$dir}/../../work/{$project}/.scm";

    mkdir "{$dir}/../../work/{$project}/.scm" unless "{$dir}/../../work/{$project}/.scm".IO ~~ :d;

    shell("git ls-remote {$scm-url} {$scm-branch} | awk '\{ print \$1 \}' 1>{$dir}/../../work/{$project}/.scm/current.commit 2>{$dir}/../../work/{$project}/.scm/git-ls-remote.err");

    my $current-commit = "{$dir}/../../work/{$project}/.scm/current.commit".IO.slurp.chomp;

    my $current-commit-short = $current-commit.chop(32);

    if $current-commit ~~ /\S/ {

      my $last-commit;
      my $trigger-build = False;

      if  "{$dir}/../../work/{$project}/.scm/last.commit".IO ~~ :f {
        $last-commit = "{$dir}/../../work/{$project}/.scm/last.commit".IO.slurp;
        if $current-commit ne $last-commit {
          $trigger-build = True;
         "{$dir}/../../work/{$project}/.scm/last.commit".IO.spurt($current-commit);
        }

      } else {
        "{$dir}/../../work/{$project}/.scm/last.commit".IO.spurt($current-commit);
        $trigger-build = True;
      }

      if $trigger-build {

        my $id = "{('a' .. 'z').pick(20).join('')}{$*PID}";

        mkdir "$dir/.triggers";

        my %trigger = %( description => "run by scm {$scm-branch} [{$current-commit-short}]" );

        %trigger<sparrowdo> = %( tags => "SCM_SHA={$current-commit-short},SCM_URL={$scm-url},SCM_BRANCH={$scm-branch}" );

        spurt "$dir/.triggers/$id", %trigger.perl;

      }

    }

  } elsif !%config<crontab>  {
      say "{DateTime.now} --- [$project] crontab entry not found, consider manual start or set up cron later, SKIP ... ";
      return;
  }


}

sub find-triggers ($root) is export {

  my @triggers;

  for dir($root) -> $dir {

    next if "$dir".IO ~~ :f;
    next if $dir.basename eq '.git';
    next if $dir.basename eq '.reports';
    next if $dir.basename eq 'db.sqlite3-journal';
    next unless "$dir/sparrowfile".IO ~~ :f;

    my $project = $dir.IO.basename;

    if "{$dir}/.triggers/".IO ~~ :d {
      for dir("{$dir}/.triggers/") -> $file {
        my %trigger = EVALFILE($file);
        %trigger<project> = $project;
        %trigger<file> = $file;
        %trigger<dt> = $file.IO.modified.DateTime;
        %trigger<data> = $file.IO.slurp;
        push @triggers, %trigger;
      }
    }

  }

  return @triggers;
}

sub trigger-exists ($root,$project,$trigger) is export {

  if "{$root}/$project/.triggers/{$trigger}".IO ~~ :f {
    return True
  } else {
    return False
  }

}
