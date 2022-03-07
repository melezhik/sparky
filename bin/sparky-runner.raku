#!/usr/bin/env raku

use Sparky;
use Data::Dump;
use YAMLish;

state $DIR;
state $MAKE-REPORT;

state %CONFIG;
state $SPARKY-BUILD-STATE;
state $SPARKY-PROJECT;
state $SPARKY-BUILD-ID;

sub MAIN (
  Str  :$dir = "$*CWD",
  Bool :$make-report = False,
  Str  :$marker,
  Str  :$trigger?,
)
{

  $DIR = $dir;

  $MAKE-REPORT = $make-report;

  my $project = $dir.IO.basename;

  $SPARKY-PROJECT = $project;

  my $reports-dir = "$dir/../.reports/$project".IO.absolute;

  my %config = read-config($dir);

  mkdir $dir;

  my $build-cache-dir = "$dir/../../work/$project/.triggers".IO.absolute;

  mkdir $build-cache-dir; # cache dir for triggered builds

  my $build_id;

  my $dbh;

  my $run-first-time = False;

  my %trigger =  Hash.new;

  if $trigger {
    say "loading trigger $trigger into Raku ...";
    %trigger = EVALFILE($trigger);
  }

  if $make-report {

    mkdir $reports-dir;

    $dbh = get-dbh( $dir );

    my $description = %trigger<description>;
    my $key = $trigger.IO.basename;

    my $sth = $dbh.prepare(q:to/STATEMENT/);
      INSERT INTO builds (project, state, description, job_id)
      VALUES ( ?,?,?,? )
    STATEMENT

    $sth.execute($project, 0, $description, $key);

    $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT max(ID) AS build_id
        FROM builds
        STATEMENT

    $sth.execute();

    my @rows = $sth.allrows();
    $build_id = @rows[0][0];

    $sth.finish;

    $SPARKY-BUILD-ID = $build_id;


    $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT count(*) AS build_cnt
        FROM builds
        WHERE project = ?
        STATEMENT

    $sth.execute($project);

    @rows = $sth.allrows();

    my $build_cnt = @rows[0][0];

    $sth.finish;

    if $build_cnt == 1 {
      $run-first-time = True;
      say "RUN BUILD $project" ~ '@' ~ $build_id ~ ' (first time)';
    } else {
      say "RUN BUILD $project" ~ '@' ~ $build_id;
    }

  } else {

    say "RUN BUILD <$project>";

  }

  my $sparrowdo-run = "sparrowdo --prefix=$project";

  my %sparrowdo-config = %config<sparrowdo> || Hash.new;

  if %trigger<sparrowdo> {
    for %trigger<sparrowdo>.keys -> $k {
      %sparrowdo-config{$k} = %trigger<sparrowdo>{$k};
    }
    # handle conflicting parameters
    if %trigger<sparrowdo><localhost> {
      %sparrowdo-config<docker>:delete;
      %sparrowdo-config<host>:delete;
    } elsif %trigger<sparrowdo><host> {
      %sparrowdo-config<docker>:delete;
      %sparrowdo-config<localhost>:delete;
    } elsif %trigger<sparrowdo><docker> {
      %sparrowdo-config<host>:delete;
      %sparrowdo-config<localhost>:delete;
    }
    if %trigger<sparrowdo><sudo> {
      %sparrowdo-config<no_sudo>:delete;
    }
  }

  say "merged sparrowdo configuration: {Dump(%sparrowdo-config)}";

  if $trigger {
    say "moving trigger to {$build-cache-dir}/{$trigger.IO.basename} ...";
    my %t = EVALFILE($trigger);
    %t<sparrowdo> = %sparrowdo-config;
    unlink $trigger;
    "{$build-cache-dir}/{$trigger.IO.basename}".IO.spurt(%t.perl);
  }

  if %sparrowdo-config<docker> {
    $sparrowdo-run ~= " --docker=" ~ %sparrowdo-config<docker>;
  } elsif %sparrowdo-config<host> {
    $sparrowdo-run ~= " --host=" ~ %sparrowdo-config<host>;
  } else {
    %sparrowdo-config<localhost> = True;
    $sparrowdo-run ~= " --localhost";
  }


  if %sparrowdo-config<repo> {
    $sparrowdo-run ~= " --repo=" ~ %sparrowdo-config<repo>;
  }

  if %sparrowdo-config<sync> {
    $sparrowdo-run ~= " --sync=" ~ %sparrowdo-config<sync>;
  }

  if %sparrowdo-config<no_sudo> {
    $sparrowdo-run ~= " --no_sudo";
  }

  if %sparrowdo-config<conf> {
    $sparrowdo-run ~= " --conf=" ~ %sparrowdo-config<conf>;
  }

  if %sparrowdo-config<no_index_update> and ! $run-first-time {
    $sparrowdo-run ~= " --no_index_update";
  }

  if %sparrowdo-config<ssh_user> {
    $sparrowdo-run ~= " --ssh_user=" ~ %sparrowdo-config<ssh_user>;
  }

  if  %sparrowdo-config<ssh_private_key> {
    $sparrowdo-run ~= " --ssh_private_key=" ~ %sparrowdo-config<ssh_private_key>;
  }

  if %sparrowdo-config<ssh_port> {
    $sparrowdo-run ~= " --ssh_port=" ~ %sparrowdo-config<ssh_port>;
  }


  if  %sparrowdo-config<tags> {
    %sparrowdo-config<tags> ~= ",SPARKY_PROJECT={$project}";
    %sparrowdo-config<tags> ~= ",SPARKY_JOB_ID={$trigger.IO.basename}" if $trigger;
    %sparrowdo-config<tags> ~= ",SPARKY_WORKER=docker" if %sparrowdo-config<docker>;
    %sparrowdo-config<tags> ~= ",SPARKY_WORKER=localhost" if %sparrowdo-config<localhost>;
    %sparrowdo-config<tags> ~= ",SPARKY_WORKER=host" if %sparrowdo-config<host>;
    %sparrowdo-config<tags> ~= ",SPARKY_TCP_PORT={sparky-tcp-port()}";
    %sparrowdo-config<tags> ~= ",SPARKY_API_TOKEN={sparky-api-token()}" if sparky-api-token();
    %sparrowdo-config<tags> ~= ",SPARKY_USE_TLS=1" if sparky-use-tls();
    $sparrowdo-run ~= " --tags='{%sparrowdo-config<tags>}'";
  } elsif $trigger {
    $sparrowdo-run ~= " --tags=SPARKY_PROJECT={$project},SPARKY_JOB_ID={$trigger.IO.basename},SPARKY_TCP_PORT={sparky-tcp-port()}";
    $sparrowdo-run ~= ",SPARKY_WORKER=docker" if %sparrowdo-config<docker>;
    $sparrowdo-run ~= ",SPARKY_WORKER=localhost" if %sparrowdo-config<localhost>;
    $sparrowdo-run ~= ",SPARKY_WORKER=host" if %sparrowdo-config<host>;
    $sparrowdo-run ~= ",SPARKY_API_TOKEN={sparky-api-token()}" if sparky-api-token();
    $sparrowdo-run ~= ",SPARKY_USE_TLS" if sparky-use-tls();
  }

  if %sparrowdo-config<verbose> {
    $sparrowdo-run ~= " --verbose";
  }

  if %sparrowdo-config<debug> {
    $sparrowdo-run ~= " --debug";
  }

  %sparrowdo-config<bootstrap> = True if %sparrowdo-config<bootstrap>;

  if  %sparrowdo-config<bootstrap> {
    $sparrowdo-run ~= " --bootstrap";
  }

  my $run-dir = $dir;

  if %trigger<cwd> {

    $run-dir = %trigger<cwd>;

  }

  if $make-report {
    my $report-file = "$reports-dir/build-$build_id.txt";
    shell("cd $run-dir && $sparrowdo-run 1>$report-file" ~ ' 2>&1');
  } else{
    shell("cd $run-dir && $sparrowdo-run" ~ ' 2>&1');
  }


  if $make-report {
    $dbh.do("UPDATE builds SET state = 1 WHERE id = $build_id");
    say "BUILD SUCCEED $project" ~ '@' ~ $build_id;
    $SPARKY-BUILD-STATE="OK";
  } else {
    $SPARKY-BUILD-STATE="OK";
    say "BUILD SUCCEED <$project>";

  }

  CATCH {

      # will definitely catch all the exception
      default {
        warn .say;
        if $make-report {
          say "BUILD FAILED $project" ~ '@' ~ $build_id;
          $dbh.do("UPDATE builds SET state = -1 WHERE id = $build_id");
          $SPARKY-BUILD-STATE="FAILED";

        } else {
          say "BUILD FAILED <$project>";
          $SPARKY-BUILD-STATE="FAILED";
        }
      }

  }

  # remove old builds

  if %config<keep_builds> and $make-report {

    say "keep builds: " ~ %config<keep_builds>;

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT id, job_id from builds where project = ? order by id asc
    STATEMENT

    $sth.execute($project);

    my @rows = $sth.allrows();

    my $all-builds = @rows.elems;

    $sth.finish;

    my $remove-builds = $all-builds - %config<keep_builds>;

    if $remove-builds > 0 {
      my $i=0;
      for @rows -> @r {
        $i++;
        my $bid = @r[0];
        my $key = @r[1];
        if $i <= $remove-builds {
          if $dbh.do("delete from builds WHERE id = $bid") {
            say "remove build database entry: $project" ~ '@' ~ $bid;
          } else {
            say "!!! can't remove build database entry: <$project>" ~ '@' ~ $bid;
          }
          if unlink "$reports-dir/build-$bid.txt".IO {
            say "remove report: $reports-dir/build-$bid.txt";
          } else {
            say "!!! can't remove report: $reports-dir/build-$bid.txt";
          }
          if $key {
            if unlink "{$build-cache-dir}/{$key}".IO {
              say "remove trigger cache: {$build-cache-dir}/{$key}";
            } else {
              say "!!! can't remove trigger cache: {$build-cache-dir}/{$key}";
            }
          }

        }

      }

    }

  }


}

sub read-config ( $dir ) {

  my %config = Hash.new;

  if "$dir/sparky.yaml".IO ~~ :f {
    my $yaml-str = slurp "$dir/sparky.yaml";
    $yaml-str ~~ s:g/'%' BUILD '-' ID '%'/$SPARKY-BUILD-ID/  if $SPARKY-BUILD-ID;
    $yaml-str ~~ s:g/'%' BUILD '-' STATE '%'/$SPARKY-BUILD-STATE/ if $SPARKY-BUILD-STATE;
    $yaml-str ~~ s:g/'%' PROJECT '%'/$SPARKY-PROJECT/ if $SPARKY-PROJECT;
    %config = load-yaml($yaml-str);

  }

  return %config;

}

LEAVE {

  # Run Sparky plugins

  my %config =  read-config($DIR);

  if  %config<plugins> {
    my $i =  %config<plugins>.iterator;
    for 1 .. %config<plugins>.elems {
      my $plg = $i.pull-one;
      my $plg-name = $plg.keys[0];
      my %plg-params = $plg{$plg-name}<parameters>;
      my $run-scope = $plg{$plg-name}<run_scope> || 'anytime';

      #say "$plg-name, $run-scope, $SPARKY-BUILD-STATE";
      if ( $run-scope eq "fail" and $SPARKY-BUILD-STATE ne "FAILED" ) {
        next;
      }

      if ( $run-scope eq "success" and $SPARKY-BUILD-STATE ne "OK" ) {
        next;
      }

      say "Load Sparky plugin $plg-name ...";
      require ::($plg-name);
      say "Run Sparky plugin $plg-name ...";
      ::($plg-name ~ '::&run')(
          {
            project => $SPARKY-PROJECT,
            build-id => $SPARKY-BUILD-ID,
            build-state => $SPARKY-BUILD-STATE,
          },
          %plg-params
      );

    }
  }

  say ">>>>>>>>>>>>>>>>>>>>>>>>>>>";
  say "BUILD SUMMARY";
  say "STATE: $SPARKY-BUILD-STATE";
  say "PROJECT: $SPARKY-PROJECT";
  say "CONFIG: " ~ Dump(%config, :color(!$MAKE-REPORT));
  say ">>>>>>>>>>>>>>>>>>>>>>>>>>>";


  # run downstream project
  if %config<downstream> {

    say "SCHEDULE BUILD for DOWNSTREAM project <" ~ %config<downstream> ~ "> ... \n";

    my $downstream_dir = ("$DIR/../" ~ %config<downstream>).IO.absolute;

    my $id = "{('a' .. 'z').pick(20).join('')}{$*PID}";

    mkdir "$downstream_dir/.triggers";

    spurt "$downstream_dir/.triggers/$id", "%(
      description => 'triggered by {$SPARKY-PROJECT}\@{$SPARKY-BUILD-ID}',
    )";

    # fixme: we need to set --make-report
    # to trigger file
    # so that schedule-build function
    # inherit make-report option
    # from ustream build


  }

}
