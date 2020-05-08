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
  Str  :$trigger?
)
{

  $DIR = $dir;

  $MAKE-REPORT = $make-report;

  my $project = $dir.IO.basename;

  $SPARKY-PROJECT = $project;

  my $reports-dir = "$dir/../.reports/$project".IO.absolute;

  my %config = read-config($dir);

  mkdir $dir;

  my $build_id;

  my $dbh;

  my $run-first-time = False;

  my %trigger =  Hash.new;

  if $trigger {
    %trigger = EVALFILE($trigger);
    unlink $trigger;
  }

  if $make-report {

    mkdir $reports-dir;

    $dbh = get-dbh( $dir );

    my $description = %trigger<description>;
    my $key = $trigger.IO.basename;

    my $sth = $dbh.prepare(q:to/STATEMENT/);
      INSERT INTO builds (project, state, description, key)
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

  if %sparrowdo-config<docker> {
    $sparrowdo-run ~= " --docker=" ~ %sparrowdo-config<docker>;
  } elsif %sparrowdo-config<host> {
    $sparrowdo-run ~= " --host=" ~ %sparrowdo-config<host>;
  } else {
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

  if  %sparrowdo-config<verbose> {
    $sparrowdo-run ~= " --verbose";
  }

  if  %sparrowdo-config<debug> {
    $sparrowdo-run ~= " --debug";
  }

  %sparrowdo-config<bootstrap> = True unless %sparrowdo-config<bootstrap>:exists;

  if  %sparrowdo-config<bootstrap> {
    $sparrowdo-run ~= " --bootstrap";
  }



  my $run-dir = $dir;

  if %trigger<cwd> {

    $run-dir = %trigger<cwd>;

  }

  if %trigger<conf> {

    $sparrowdo-run ~= " --conf={%trigger<conf>}";

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
        SELECT id from builds where project = ? order by id asc
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
        if $i <= $remove-builds {
          if $dbh.do("delete from builds WHERE id = $bid") {
            say "remove build $project" ~ '@' ~ $bid;
          } else {
            say "!!! can't remove build <$project>" ~ '@' ~ $bid;
          }
          if unlink "$reports-dir/build-$bid.txt".IO {
            say "remove $reports-dir/build-$bid.txt";
          } else {
            say "!!! can't remove $reports-dir/build-$bid.txt";
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
      description => "triggered by {$SPARKY-PROJECT}@{$SPARKY-BUILD-ID}",
    )";

    # fixme: we need to pass --make-report in
    # schedule-build function
    # to inherit make-report option
    # from ustream build
    # for build runs from cli

    schedule-build "$root/$project";

  }

}
