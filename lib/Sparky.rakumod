use v6;

unit module Sparky:ver<0.2.10>;
use YAMLish;
use DBIish;
use Time::Crontab;

my $root = %*ENV<SPARKY_ROOT> || %*ENV<HOME> ~ '/.sparky/projects';
my %conf;

sub sparky-http-root is export {

  %*ENV<SPARKY_HTTP_ROOT> || "";

}

sub sparky-host is export {

  get-sparky-conf()<SPARKY_HOST> || "0.0.0.0";

}

sub sparky-use-tls is export {

  get-sparky-conf()<SPARKY_USE_TLS>;

}

sub sparky-tls-settings is export {
  get-sparky-conf()<tls>
}

sub sparky-tcp-port is export {

  get-sparky-conf()<SPARKY_TCP_PORT> || 4000;

}

sub sparky-api-token is export {

  get-sparky-conf()<SPARKY_API_TOKEN>;

}

sub sparky-auth is export {
  get-sparky-conf()<auth> || %(
    default => True,
    users => [
      {
        login => "admin",
        # default password is admin
        password => "456b7016a916a4b178dd72b947c152b7" # md5sum('admin')
      },
    ]  
  );
}

sub sparky-with-flapper is export {

  ! ( get-sparky-conf()<worker><flappers_off> || False ) &&
  ! %*ENV<SPARKY_FLAPPERS_OFF> 

}

sub sparky-allow-rebuild-spawn is export {

  get-sparky-conf()<SPARKY_ALLOW_REBUILD_SPAWN> || False;

}

sub get-sparky-conf is export {

  return %conf if %conf;
 
  my $conf-file = %*ENV<HOME> ~ '/sparky.yaml';

  # say ">>> ", $conf-file.IO.slurp;

  # say ">>> parse sparky yaml config from: $conf-file";

  %conf = $conf-file.IO ~~ :f ?? load-yaml($conf-file.IO.slurp) !! Hash.new;

  return %conf;

}

sub get-database-engine is export {

  my %conf = get-sparky-conf();

  if %conf<database> && %conf<database><engine> {
    return %conf<database><engine>
  } else {
    return "sqlite"
  }
}

multi sub get-dbh ( $dir ) is export {

  #return $dbh if $dbh;
  
  my $dbh;

  my %conf = get-sparky-conf();

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

    say "{DateTime.now} --- load sqlite dbh for: " ~ ("$dir/../db.sqlite3".IO.absolute);

  }

  return $dbh

}


multi sub get-dbh {

  #return $dbh if $dbh;

  my $dbh;

  my %conf = get-sparky-conf();

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

  return $dbh;

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

sub builds-running-cnt {

  my @proc-check-cmd = ("bash", "-c", "ps aux | grep sparky-runner.raku | grep -v grep | wc -l");

  my $proc-run = run @proc-check-cmd, :out;

  if $proc-run.exitcode == 0 {

      $proc-run.out.get ~~ m/(\d+)/;

      my $cnt = $0;

      say "{DateTime.now} --- sparky jobs running, cnt:  $cnt";

      return $cnt

  } else {

    return 0
  }

}

sub schedule-build ( $dir, %opts? ) is export {

  my $project = $dir.IO.basename;

  my %config = Hash.new;

  #my $jobs-cnt = builds-running-cnt();

  #if %*ENV<SPARKY_MAX_JOBS> {
  #  if $jobs-cnt >= %*ENV<SPARKY_MAX_JOBS> {
  #      say "{DateTime.now} --- $jobs-cnt builds run, SPARKY_MAX_JOBS={%*ENV<SPARKY_MAX_JOBS>}, SKIP ... ";
  #      return;
  #  }
  #}

  if "$dir/sparky.yaml".IO ~~ :f {

    say "{DateTime.now} --- sparkyd: parse sparky job yaml config from: $dir/sparky.yaml";

    try { %config = load-yaml(slurp "$dir/sparky.yaml") };

    if $! {
      my $error = $!;
      say "{DateTime.now} --- sparkyd: error parsing $dir/sparky.yaml";
      say $error;
      return "{DateTime.now} --- sparkyd: remove build from schedulling"
    }

  }

  if %config<disabled>  {
    say "{DateTime.now} --- [$project] build is disabled, SKIP ... ";
    return;
  }

  # check  triggered jobs

  my $trigger-file;
  my $run-by-trigger = False;

  if "{$dir}/.triggers/".IO ~~ :d {
    for dir("{$dir}/.triggers/".sort({.IO.changed})) -> $file {
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

  # schedulling cron jobs

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
    } elsif %config<scm>  {
      say "{DateTime.now} --- [$project] build is skipped by cron, by will be tried on scm basis";
    } else  {
      say "{DateTime.now} --- [$project] build is skipped by cron: $crontab ... ";
      return;
    }
  } 

  # schedulling scm jobs

  if %config<scm> {

    my $scm-url = %config<scm><url>;

    my $scm-branch = %config<scm><branch> || 'master';

    my $scm-dir =   "{$dir}/../../work/{$project}/.scm";

    mkdir $scm-dir unless $scm-dir.IO ~~ :d;

    say "{DateTime.now} --- scm: fetch commits from {$scm-url} {$scm-branch} ...";

    shell("timeout 10 git ls-remote {$scm-url} {$scm-branch} 1>{$scm-dir}/data; echo \$? > {$scm-dir}/exit-code");

    my $ex-code = "{$scm-dir}/exit-code".IO.slurp.chomp;

    if $ex-code ne "0" {
      say "{DateTime.now} --- scm: {$scm-url} {$scm-branch} - bad exit code - {$ex-code}";
      return $ex-code;
    } else {
      say "{DateTime.now} --- scm: {$scm-url} {$scm-branch} - good exit code - {$ex-code}";
    }

    my $commit-data = "{$scm-dir}/data".IO.slurp.chomp;

    my $current-commit;

    if $commit-data ~~ /^^ (\S+) / {
      $current-commit = "{$0}";
    }
    
    my $current-commit-short = ($current-commit ~~ /\S/) ?? $current-commit.chop(32) !! "HEAD";

    if $current-commit ~~ /\S/ {

      my $last-commit;

      my $trigger-build = False;

      if  "{$scm-dir}/last.commit".IO ~~ :f {
        $last-commit = "{$scm-dir}/last.commit".IO.slurp;
        if $current-commit ne $last-commit {
          $trigger-build = True;
         "{$scm-dir}/last.commit".IO.spurt($current-commit);
        }

      } else {
        "{$scm-dir}/last.commit".IO.spurt($current-commit);
        $trigger-build = True;
      }

      if $trigger-build {

        my $id = "{('a' .. 'z').pick(20).join('')}{$*PID}";

        mkdir "$dir/.triggers";

        my %trigger = %( 
          description => "run by scm {$scm-branch} [{$current-commit-short}]" 
        );

        %trigger<sparrowdo> = %( 
          tags => "SCM_SHA={$current-commit-short},SCM_URL={$scm-url},SCM_BRANCH={$scm-branch}" 
        );

        spurt "$dir/.triggers/$id", %trigger.perl;

      }

    }

    return;

  } 

  # handle other jobs (none crontab and scm)

  if !%config<crontab> && !%config<scm> {
      say "{DateTime.now} --- [$project] neither crontab  nor scm setup found, consider manual start, SKIP ... ";
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
        say ">> load trigger from file $file ...";
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

sub trigger-exists ($root,$project,$job-id) is export {

  if "{$root}/$project/.triggers/{$job-id}".IO ~~ :f {
    return True
  } else {
    return False
  }

}

sub job-state-exists ($root,$project,$job-id) is export {

  if "{$root}/../work/$project/.states/$job-id".IO ~~ :f {
    return True
  } else {
    return False
  }

}

sub job-state ($root,$project,$job-id) is export {

  "{$root}/../work/$project/.states/$job-id".IO.slurp

}

sub cache-root is export {

  "{%*ENV<HOME>}/.sparky/";

}
