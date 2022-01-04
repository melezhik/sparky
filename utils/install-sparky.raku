use Sparky::JobApi;

my $ssh-user = tags()<ssh-user>  || "sparky";

if ! tags()<stage> {

    my $status;

    my $j = Sparky::JobApi.new();

    $j.queue({
      description => "sparky libs",
      tags => %(
        stage => "libs",
      ),
      sparrowdo => %(
        bootstrap => True,
        sudo => True,
        host => tags()<ip>,
        ssh_user => $ssh-user
      );
    });

    say "queue spawned job, ",$j.info.perl;
  
    my $supply = supply { while True {  emit $j.status; done if $j.status eq "FAIL" or $j.status eq "OK"; sleep(5) } }

    $supply.tap( -> $v { say $v; $status = $v } );

    die unless $status eq "OK";

    $j = Sparky::JobApi.new();

    $j.queue({
      description => "sparky rakulibs",
      tags => %(
        stage => "rakulibs",
      ),
      sparrowdo => %(
        bootstrap => False,
        no_sudo => True,
        host => tags()<ip>,
        ssh_user => $ssh-user,
      );
    });

    say "queue spawned job, ",$j.info.perl;
  
    $supply = supply { while True {  emit $j.status; done if $j.status eq "FAIL" or $j.status eq "OK"; sleep(5) } }

    $supply.tap( -> $v { say $v; $status = $v } );

    die unless $status eq "OK";

} elsif tags()<stage> && tags()<stage> eq "libs" {

    package-install "libssl-dev";

}  elsif tags()<stage> && tags()<stage> eq "rakulibs" {

  bash "zef --version || /opt/rakudo-pkg/bin/install-zef";

  for 'https://github.com/melezhik/sparrowdo.git',
      'https://github.com/melezhik/sparky.git',
      'https://github.com/melezhik/sparky-job-api.git' -> $i {

      zef $i, %( notest => True );

  }

}


