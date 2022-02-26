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

    my @q;

    for config()<workers><> -> $w {

      my $j = self.new-job: :project("update-sparky"), :api($w<api>);

      $j.queue({
        description => "sparky update",
        tags => %(
          stage => "update",
        ),
        #sparrowdo => %(
        #  no_sudo => True,
        #  bootstrap => False
        #),
      });

      say "queue spawned job, ",$j.info.perl;
      @q.push: $j;

    }

    my $s = self.wait-jobs(@q);

    die if $s<FAIL>;

  }

}

Pipeline.new.run;  
