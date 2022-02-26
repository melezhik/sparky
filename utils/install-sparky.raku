use Sparky::JobApi;

class Pipeline does Sparky::JobApi::Role {

  has Str $.comp = tags()<comp> || "main";
  has Str $.ssh-user = tags()<ssh-user>  || "sparky";
  has Str $.host = tags()<host> || "";
  has Str $.name = tags()<name> || "";
  has Str $.api-token =  tags()<api-token> || "";
  has Str $.ssl = tags()<ssl> || "True";

  method !queue-libs() {

    my $j = self.new-job;

    say "host={$.host}";
    say "ssh_user={$.ssh-user}";

    $j.queue({
      description => "sparky libs on {$.name}",
      tags => %(
        stage => "libs",
        host => $.host,
        name => $.name,
        ssh-user => $.ssh-user,
      ),
      sparrowdo => %(
        bootstrap => True,
        sudo => True,
        host => $.host,
        ssh_user => $.ssh-user,
        verbose => True,
      );
    });

    say "queue spawned job, ",$j.info.perl;

    my $s = self.wait-job($j); 

    die if $s<FAIL>;

  }

  method !queue-raku-libs() {

    my $j = self.new-job;

    $j.queue({
      description => "sparky raku libs on {$.name}",
      tags => %(
        stage => "raku-libs",
        host => $.host,
        name => $.name,
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

    my $s = self.wait-job($j);

    die if $s<FAIL>;

  }

  method !queue-services() {

    my $j = self.new-job;

    $j.queue({
      description => "sparky services on {$.name}",
      tags => %(
        stage => "services",
        host => $.host,
        name => $.name,
        ssh-user => $.ssh-user,
        ssl => $.ssl,
      ),
      sparrowdo => %(
        bootstrap => False,
        no_sudo => False,
        host => $.host,
        ssh_user => $.ssh-user,
      );
    });

    say "queue spawned job, ",$j.info.perl;

    my $s = self.wait-job($j);

    die if $s<FAIL>;

  }


  method stage-main() {

    my @q;  

    for config()<workers><> -> $w {

      my $j = self.new-job: :project("install-sparky-{$w<host>}");

      $j.queue({
        description => "bootstrap sparky on {$w<name>}",
        tags => %(
          stage => "worker",
          host => $w<host>,
          name => $w<name>,
          ssh-user => $w<ssh-user>,
          ssl => $.ssl,
          comp => $.comp,
        ),
      });

      @q.push: $j;

      say "queue spawned job:", $j.info.perl;

    }

    my $s = self.wait-jobs(@q);

    die if $s<FAIL>;


  }
  
  method stage-worker() {
  
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

    bash "if test -f ~/.sparky/projects/db.sqlite3; then echo db.sqlite3 exists; else raku db-init.raku; fi", %(
      description => "create sparky database",
      cwd => "/home/{$.ssh-user}/projects/Sparky"
    );

  }

  method stage-services() {

    my $sc; # sparky config

    if $.api-token { 
      $sc~="SPARKY_API_TOKEN: {$.api-token}\n";
    }

    if $.ssl eq 'True' {

      $sc~="SPARKY_USE_TLS: True\n";

        my %state = task-run "create", "openssl-cert", %(
          CN => "www.{$.host}"
        );

        file "/home/{$.ssh-user}/.sparky/key", %(
          owner => "{$.ssh-user}",
          content => %state<key>,
        );  

        file "/home/{$.ssh-user}/.sparky/cert", %(
          owner => "{$.ssh-user}",
          content => %state<cert>,
        );

      $sc~="tls:\n private-key-file: /home/{$.ssh-user}/.sparky/key\n";
      $sc~="\n certificate-file: /home/{$.ssh-user}/.sparky/cert\n";

    }

    "/home/{$.ssh-user}/sparky.yaml".IO.spurt($sc);

    systemd-service "sparky-web", %(
      user => $.ssh-user,
      workdir => "/home/{$.ssh-user}/projects/Sparky",
      command => "/usr/bin/bash --login -c 'export PATH=~/.raku/bin:\$PATH && cd /home/{$.ssh-user}/projects/Sparky && cro run'"
    );

    systemd-service "sparkyd", %(
      user => $.ssh-user,
      workdir => "/home/{$.ssh-user}/projects/Sparky",
      command => "/usr/bin/bash --login -c 'export PATH=~/.raku/bin:\$PATH && sparkyd'"
    );

    sleep(3);

    bash "systemctl daemon-reload";

    service-restart "sparky-web";

    service-enable "sparky-web";

    service-restart "sparkyd";

    service-enable "sparkyd";

  }

}


Pipeline.new.run();

