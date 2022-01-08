  if tags()<stage> eq "main" {

    # spawns a child job

    use Sparky::JobApi;
    my $j = Sparky::JobApi.new(:api<http://sparrowhub.io:4000>);
    $j.queue({
      description => "my spawned job",
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
      #sparrowdo => %(
      #  no_sudo => True,
      #  bootstrap => False
      #)
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
  } elsif tags()<stage> eq "child" {

    # child job here

    sleep(10);

    say "config: ", config().perl;
    say "tags: ", tags().perl;

  }
