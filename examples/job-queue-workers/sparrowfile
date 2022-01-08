if tags()<stage> eq "main" {

    use Sparky::JobApi;

    my $j = Sparky::JobApi.new(:workers<90>);

    $j.queue({
      description => "spawned job", 
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job ", $j.info;

} elsif tags()<stage> eq "child" {

  say "I am a child scenario";
  say "config: ", config().perl;
  say "tags: ", tags().perl;

}
