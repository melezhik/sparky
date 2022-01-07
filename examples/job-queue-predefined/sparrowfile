use Sparky::JobApi;

if tags()<stage> eq "main" {

    my $rand = ('a' .. 'z').pick(20).join('');

    my $job-id = "{$rand}_1";

    Sparky::JobApi.new(:project<worker_1>,:$job-id).queue({
      description => "spawned job. 03.1",
      tags => %(
        seed => $rand,
        stage => "child",
        i => 1,
      ),
    });

    my @jobs;

    # wait all 10 recursively launched jobs
    # that are not yet launched by that point
    # but will be launched recursively
    # in "child" jobs 

    for 1 .. 10 -> $i {

      my $supply = supply {

        my $project = "worker_{$i}";

        my $job-id = "{$rand}_{$i}";

        my $j = Sparky::JobApi.new(:$project,:$job-id);

        while True {

          my $status = $j.status;

          emit %( id => "{$project}/{$job-id}", status => $status );

          done if $status eq "FAIL" or $status eq "OK";

          sleep(1);

        }

      }

      $supply.tap( -> $v {
        push @jobs, $v if $v<status> eq "FAIL" or $v<status> eq "OK";
        say $v;
      });

    }

    say @jobs.grep({$_<status> eq "OK"}).elems, " jobs finished successfully";
    say @jobs.grep({$_<status> eq "FAIL"}).elems, " jobs failed";
    say @jobs.grep({$_<status> eq "TIMEOUT"}).elems, " jobs timeouted";

  } elsif tags()<stage> eq "child" {

    say "I am a child job!";

    say tags().perl;

    if tags()<i> < 10 {

      my $i = tags()<i>.Int + 1;

      # do some useful stuff here
      # and launch another recursive job
      # with predefined project and job ID
      # i tagged variable gets incremented
      # recursively launched jobs
      # get waited in a "main" scenario 

      my $project = "worker_{$i}"; 
      my $job-id = "{tags()<seed>}_{$i}";

      Sparky::JobApi.new(:$project,:$job-id).queue({
        description => "spawned job. 03.{$i}",
        tags => %(
          seed => tags()<seed>,
          stage => "child",
          i => $i,
        ),
      });
   }
}

