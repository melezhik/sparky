if tags()<stage> eq "main" {

    use Sparky::JobApi;

    my $j = Sparky::JobApi.new(:project<spawned_01>);

    $j.queue({
      description => "spawned job. 01", 
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "job info: ", $j.info.perl;

} elsif tags()<stage> eq "child" {

  say "I am a child scenario";
  say "config: ", config().perl;
  say "tags: ", tags().perl;

}
