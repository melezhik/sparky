  use Sparky::JobApi;

  if tags()<stage> eq "main" {

    # spawns a child job

    my $j = Sparky::JobApi.new(:project<spawned_jobs>);
    $j.queue({
      description => "my spawned job",
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job, ",$j.info.perl;

    my $supply = supply {

        while True {

          my $status = $j.status;

          emit %( job-id => $j.info<job-id>, status => $status );

          done if $status eq "FAIL" or $status eq "OK";

          sleep(5);

        }
    }

    $supply.tap( -> $v {
        say $v;
    });

    say $j.get-stash().perl;


  } elsif tags()<stage> eq "child" {

    # child job here

    say "config: ", config().perl;
    say "tags: ", tags().perl;

    my $j = Sparky::JobApi.new( mine => True );

    $j.put-stash({ hello => "Sparky" });

  }
