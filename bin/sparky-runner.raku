#!/usr/bin/env raku

use Sparky;
use Data::Dump;
use YAMLish;
use File::Directory::Tree;
use Sparky::Utils;

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

  say "load sparky.yaml config from $dir ..";
  say ">>>", Dump(%config);
  mkdir $dir;

  my $build-cache-dir = "$dir/../../work/$project/.triggers".IO.absolute;
  my $build-state-dir = "$dir/../../work/$project/.states".IO.absolute;
  my $build-files-dir = "$dir/../../work/$project/.files".IO.absolute;

  mkdir $build-cache-dir; # cache dir for triggered builds
  mkdir $build-state-dir; # state dir for triggered builds
  mkdir $build-files-dir; # files dir for triggered builds

  my $build_id;

  my $dbh;

  my $run-first-time = False;

  my %trigger =  Hash.new;

  my $job-id = $trigger ?? $trigger.IO.basename !! "cli_job";

  if $trigger {
    say "loading trigger $trigger into Raku ...";
    %trigger = EVALFILE($trigger);
  }

  if $make-report {

    mkdir $reports-dir;

    $dbh = get-dbh( $dir );

    my $description = %trigger<description>;

    my $sth = $dbh.prepare(q:to/STATEMENT/);
      INSERT INTO builds (project, state, description, job_id)
      VALUES ( ?,?,?,? )
    STATEMENT

    $sth.execute($project, 0, $description, $job-id);

    # SPEED optimization:
    # we use file cache instead of database
    # to return build states from http API (sparky-job-api calls f.e.)
    # states still exit in a database
    # but for the sake of speed and 
    # not to overload database with requests
    # we would rather return states
    # by reading them from static files
    # not from database entries

    "{$build-state-dir}/{$job-id}".IO.spurt(0);

    $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT max(ID) AS build_id
        FROM builds where job_id = ? 
        STATEMENT

    $sth.execute($job-id);

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

  my %shared-vars;
  my %host-vars;
  my $error;

  if "$dir/../../templates/vars.yaml".IO ~~ :f {

    say "templates: load shared vars from vars.yaml";

    try { %shared-vars = load-yaml("$dir/../../templates/vars.yaml".IO.slurp) };

    if $! {
      $error ~= $!;
      say "project/$project: error parsing $dir/../../templates/var.yaml";
      say $error;
    }

  }

  if "$dir/../../templates/hosts/{hostname()}/vars.yaml".IO ~~ :f {

    say "templates: load host vars from {hostname()}/vars.yaml";

    try { %host-vars = load-yaml("$dir/../../templates/hosts/{hostname()}/vars.yaml".IO.slurp) };

    if $! {
      $error ~= $!;
      say "project/$project: error parsing $dir/../../templates/hosts/{hostname()}/vars.yaml";
      say $error;
    }

  }

  if %trigger<sparrowdo> {
    for %trigger<sparrowdo>.keys -> $k {
      if $k eq "tags" {
        if %sparrowdo-config{$k} {
          %sparrowdo-config{$k} ~= ",{%trigger<sparrowdo>{$k}}"
        } else {
          %sparrowdo-config{$k} = %trigger<sparrowdo>{$k}
        }
      } else {
        %sparrowdo-config{$k} = %trigger<sparrowdo>{$k};
      }
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

  if %sparrowdo-config<docker> {
    $sparrowdo-run ~= " --docker=" ~ %sparrowdo-config<docker>;
  } elsif %sparrowdo-config<host> {
    $sparrowdo-run ~= " --host=" ~ %sparrowdo-config<host>;
  } else {
    %sparrowdo-config<localhost> = True;
    $sparrowdo-run ~= " --localhost";
  }

  if %sparrowdo-config<image> {
    $sparrowdo-run ~= " --image=" ~ %sparrowdo-config<image>;
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


  if %sparrowdo-config<tags> {
    for %sparrowdo-config<tags> ~~ m:global/"%" (\S+?) "%"/ -> $c {
      my $var_id = $c[0].Str;
      # apply vars from host vars first
      my $host-var = get-template-var(%host-vars<vars>,$var_id);
      if defined($host-var) {
        if $host-var.isa(Str) or $host-var.isa(Rat) or $host-var.isa(Int) {
          %sparrowdo-config<tags>.=subst("%{$var_id}%",$host-var,:g);
        } elsif $host-var.isa(Hash)  {
          my @tags;
          for $host-var.keys.sort -> $v {
              @tags.push: "$v={$host-var{$v}}"
          }
          %sparrowdo-config<tags> = @tags.join(",");
        }
        say "project/$project: sparrowdo.tags - insert tags %{$var_id}% from host vars";
        next;
      }      
      my $shared-var = get-template-var(%shared-vars<vars>,$var_id);
      if defined($shared-var) {
        if $shared-var.isa(Str) or $shared-var.isa(Rat) or $shared-var.isa(Int) {
          %sparrowdo-config<tags>.=subst("%{$var_id}%",$shared-var,:g);
        } elsif $shared-var.isa(Hash)  {
          my @tags;
          for $shared-var.keys.sort -> $v {
              @tags.push: "$v={$host-var{$v}}"
          }
          %sparrowdo-config<tags> = @tags.join(",");
        }
        say "project/$project: sparrowdo.tags - insert tags %{$var_id}% from host vars";
        next;
      }      
    }  
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

  $sparrowdo-run ~= " --color"; # enable color output

  %sparrowdo-config<bootstrap> = True if %sparrowdo-config<bootstrap>;

  if  %sparrowdo-config<bootstrap> {
    $sparrowdo-run ~= " --bootstrap";
  }

  say "merged sparrowdo configuration: {Dump(%sparrowdo-config)}";

  my $run-dir = $dir;

  if %trigger<cwd> {

    $run-dir = %trigger<cwd>;

  }

  if $trigger {
    say "moving trigger to {$build-cache-dir}/{$trigger.IO.basename} ...";
    my %t = EVALFILE($trigger);
    %t<sparrowdo> = %sparrowdo-config;
    unlink $trigger;
    "{$build-cache-dir}/{$trigger.IO.basename}".IO.spurt(%t.perl);
  }

  if $make-report {
    my $report-file = "$reports-dir/build-$build_id.txt";
    shell("export SP6_FORMAT_COLOR=1 && cd $run-dir && $sparrowdo-run 1>$report-file" ~ ' 2>&1');
  } else{
    shell("export SP6_FORMAT_COLOR=1 && cd $run-dir && $sparrowdo-run" ~ ' 2>&1');
  }


  if $make-report { $dbh.do("UPDATE builds SET state = 1 WHERE id = $build_id"); 
    say "BUILD SUCCEED $project" ~ '@' ~ $build_id; 
    $SPARKY-BUILD-STATE="OK"; 
    "{$build-state-dir}/{$job-id}".IO.spurt(1);
  } else {
    say "BUILD SUCCEED <$project>";
    $SPARKY-BUILD-STATE="OK";
    "{$build-state-dir}/{$job-id}".IO.spurt(1);
  }

  CATCH {

      # will definitely catch all the exception
      default {
        warn .say;
        if $make-report {
          say "BUILD FAILED $project" ~ '@' ~ $build_id;
          $dbh.do("UPDATE builds SET state = -1 WHERE id = $build_id");
          $SPARKY-BUILD-STATE="FAILED";
         "{$build-state-dir}/{$job-id}".IO.spurt(-1);
        } else {
          say "BUILD FAILED <$project>";
          $SPARKY-BUILD-STATE="FAILED";
         "{$build-state-dir}/{$job-id}".IO.spurt(-1);
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
        my $job-id = @r[1];
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
          if $job-id {
            if unlink "{$build-cache-dir}/{$job-id}".IO {
              say "remove trigger cache: {$build-cache-dir}/{$job-id}";
            } else {
              say "!!! can't remove trigger cache: {$build-cache-dir}/{$job-id}";
            }
            if unlink "{$build-state-dir}/{$job-id}".IO {
              say "remove state cache: {$build-state-dir}/{$job-id}";
            } else {
              say "!!! can't remove state cache: {$build-state-dir}/{$job-id}";
            }
            if "{$build-files-dir}/{$job-id}".IO ~~ :d {
              if rmtree "{$build-files-dir}/{$job-id}" {
                say "remove files dir: {$build-files-dir}/{$job-id}";
              } else {
                say "!!! can't remove files dir: {$build-files-dir}/{$job-id}";
              }
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
    for %config<plugins>.kv -> $plg-name, $plg-data {
      my %plg-params = $plg-data<parameters> || %();
      my $run-scope = $plg-data<run_scope> || 'anytime';

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

    "{$downstream_dir}/.triggers/{$id}".IO.spurt("%(
      description => 'triggered by {$SPARKY-PROJECT}\@{$SPARKY-BUILD-ID}',
    )");

    # fixme: we need to set --make-report
    # to trigger file
    # so that schedule-build function
    # inherit make-report option
    # from ustream build


  }

}
