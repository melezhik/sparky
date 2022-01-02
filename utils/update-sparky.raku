use Sparky::JobApi;

if tags()<stage> && tags<stage> eq "child" {

  for  'sparky', 'sparky-job-api', 'sparrowdo' -> $app {

    say "update [$app] ...";

    bash "cd ~/projects/$app && git pull";

    chdir "{%*ENV<HOME>}/projects/$app";

    zef '.', %( force => True );

  }


} else {

    my $status;

    my $j = Sparky::JobApi.new(:api<http://sparrowhub.io:4000>);

    $j.queue({
      description => "sparky update",
      tags => %(
        stage => "child",
      ),
      sparrowdo => %(
        no_sudo => True,
        bootstrap => False
      )
    });

    say "queue spawned job, ",$j.info.perl;

    my $supply = supply {

        while True {

          emit $j.status;

          done if $j.status eq "FAIL" or $status eq "OK";

          sleep(5);

        }
    }

    $supply.tap( -> $v {
        say $v;
        $status = $v;
    });
}

