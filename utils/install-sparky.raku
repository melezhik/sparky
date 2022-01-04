use Sparky::JobApi;

class Pipeline {

  has Str $.comp = tags()<comp> || "main";
  has Str $.ssh-user = tags()<ssh-user>  || "sparky";
  has Str $.host = tags()<ip>;
  has Str $.api-token =  tags()<api-token> || "";

  method !wait-job($j){

    my $s = supply { 
      while True {  
        emit $j.status; 
        done if $j.status eq "FAIL" or $j.status eq "OK"; 
        sleep(5) 
      } 
    }

   my $status;

   $s.tap( -> $v { say $v; $status = $v } );

   die unless $status eq "OK";

  }

  method !queue-libs() {

    my $j = Sparky::JobApi.new();

    $j.queue({
      description => "sparky libs on {$.host}",
      tags => %(
        stage => "libs",
        ip => $.host,
        ssh-user => $.ssh-user,
      ),
      sparrowdo => %(
        bootstrap => True,
        sudo => True,
        host => $.host,
        ssh_user => $.ssh-user
      );
    });

    say "queue spawned job, ",$j.info.perl;

    self!wait-job($j);

  }

  method !queue-raku-libs() {

    my $j = Sparky::JobApi.new();

    $j.queue({
      description => "sparky raku libs on {$.host}",
      tags => %(
        stage => "raku-libs",
        ip => $.host,
        ssh-user => $.ssh-user,
        api-token => $.api-token,
      ),
      sparrowdo => %(
        bootstrap => False,
        no_sudo => True,
        host => $.host,
        ssh_user => $.ssh-user,
      );
    });

    say "queue spawned job, ",$j.info.perl;

    self!wait-job($j);

  }

  method !queue-services() {

    my $j = Sparky::JobApi.new();

    $j.queue({
      description => "sparky services on {$.host}",
      tags => %(
        stage => "services",
        ip => $.host,
        ssh-user => $.ssh-user,
      ),
      sparrowdo => %(
        bootstrap => False,
        no_sudo => False,
        host => $.host,
        ssh_user => $.ssh-user,
      );
    });

    say "queue spawned job, ",$j.info.perl;

    self!wait-job($j);

  }

  method stage-main() {
  
    self!queue-libs() if $.comp eq "main" or $.comp eq "libs";

    self!queue-raku-libs() if $.comp eq "main" or $.comp eq "raku-libs";

    self!queue-services() if $.comp eq "main" or $.comp eq "services";
    
  } 

  method stage-libs {

    package-install "libssl-dev";
    package-install "libtemplate-perl carton";

  }

  method stage-raku-libs() {

    bash "zef --version || /opt/rakudo-pkg/bin/install-zef";

    for 'https://github.com/melezhik/sparrowdo.git',
        'https://github.com/melezhik/sparky.git',
        'https://github.com/melezhik/sparky-job-api.git' -> $i {

        zef $i, %( notest => True );

    }

    directory "/home/{$.ssh-user}/projects/";

    directory "/home/{$.ssh-user}/projects/Sparky";

    git-scm "https://github.com/melezhik/sparky.git", %(
      to => "/home/{$.ssh-user}/projects/Sparky";
    );

    bash "raku db-init.raku", %(
      cwd => "/home/{$.ssh-user}/projects/Sparky"
    );

    if $.api-token {
      "/home/{$.ssh-user}/sparky.yaml".IO.spurt("SPARKY_API_TOKEN: {$.api-token}");
    }

  }

  method stage-services() {

    systemd-service "sparky-web", %(
      user => $.ssh-user,
      workdir => "/home/{$.ssh-user}/projects/Sparky",
      command => "/usr/bin/bash --login -c 'export PATH=~/.raku/bin:\$PATH && cd /home/{$.ssh-user}/projects/Sparky && cro run'"
    );

    service-restart "sparky-web";

  }

}


Pipeline.new."stage-{tags()<stage>||'main'}"();

