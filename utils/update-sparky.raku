use Sparky::JobApi;

class Pipeline does Sparky::JobApi::Role {

  method stage-update {

  #bash "echo 'SPARKY_API_TOKEN: {tags()<SPARKY_API_TOKEN>}' > ~/sparky.yaml", %(
  #  description => "set token"
  #);

    for  'sparky', 'sparky-job-api', 'sparrowdo' -> $app {

      say "update [$app] ...";

      bash "cd ~/projects/$app && git pull";

      chdir "{%*ENV<HOME>}/projects/$app";

      zef '.', %( force => True );

    }

  }


  method stage-main {

    my $status;

    my $j = self.new-job: (:api<http://sparrowhub.io:4000>);

    $j.queue({
      description => "sparky update",
      tags => %(
        stage => "update",
      ),
      #sparrowdo => %(
      #  no_sudo => True,
      #  bootstrap => False
      #)
    });

    say "queue spawned job, ",$j.info.perl;

    my $s = self.wait-job($j);

    die if $s<FAIL>;

  }

}

Pipeline.new.run;  
