  if tags()<stage> eq "main" {

    use Sparky::JobApi;

    my $project = "spawned_01";

    my $j = Sparky::JobApi.new(:project<spawned_01>);

    $j.queue({
      description => "spawned job. 02", 
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
      sparrowdo => %(
        no_index_update => True
      )
    });

    say "queue spawned job ", $j.info.perl;

  } elsif tags()<stage> eq "child" {

    use Sparky::JobApi;

    say "I am a child scenario";

    my $j = Sparky::JobApi.new(:project<spawned_02>);

    $j.queue({
      description => "spawned job2. 02",
      tags => %(
        stage => "off",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job ",$j.info.perl;

  } elsif tags()<stage> eq "off" {

    say "I am off now, good buy!";
    say "config: ", config().perl;
    say "tags: ", tags().perl;

  }

