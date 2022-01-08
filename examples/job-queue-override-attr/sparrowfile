use Sparky::JobApi;

  if tags()<stage> eq "main" {

    my $j = Sparky::JobApi.new(:project<spawned_01>);

    $j.queue({
      description => "spawned job. 022", 
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
      sparrowdo => %(
        no_index_update => False
      )
    });

    say "queue spawned job ", $j.info.perl;

  } elsif tags()<stage> eq "child" {

    say "I am a child scenario";

    my $j = Sparky::JobApi.new(:project<spawned_02>);

    $j.queue({
      description => "spawned job2. 022",
      tags => %(
        stage => "off",
        foo => 1,
        bar => 2,
      ),
      sparrowdo => %(
        host => "sparrowhub.io",
        ssh_user => "root",
      )
    });

    say "queue spawned job ", $j.info.perl;

  } elsif tags()<stage> eq "off" {

    bash "hostname";

    say "I am off now, good buy!";
    say "config: ", config().perl;
    say "tags: ", tags().perl;

  }

