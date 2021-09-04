use Cro::HTTP::Server;
use Cro::HTTP::Router;
use Cro::WebApp::Template;

use DBIish;
use Sparky;
use Sparky::HTML;
use YAMLish;

my $root = %*ENV<SPARKY_ROOT> || %*ENV<HOME> ~ '/.sparky/projects';
my $reports-dir = "$root/.reports";

my $application = route { 

  post -> 'build', 'project', $project {

    my $id = "{('a' .. 'z').pick(20).join('')}{$*PID}";

    mkdir "$root/$project/.triggers";

    spurt "$root/$project/.triggers/$id", "%(
      description => 'triggered by user',
    )";

    "build queued";

  }

  post -> 'build', 'project', $project, $key {

    mkdir "$root/$project/.triggers";

    copy "$root/../work/$project/.triggers/$key", "$root/$project/.triggers/$key";

    "build queued";

  }

  get -> {
  
    my $dbh = get-dbh();

    my @projects = Array.new;

    for dir($root) -> $dir {

      next if "$dir".IO ~~ :f;
      next if $dir.basename eq '.git';
      next if $dir.basename eq '.reports';
      next if $dir.basename eq 'db.sqlite3-journal';
      next unless "$dir/sparrowfile".IO ~~ :f;

      my $project = $dir.IO.basename;

      my $sth = $dbh.prepare("SELECT max(id) as last_build_id FROM builds where project = '{$project}'");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      $sth.finish;

      my $last_build_id =  @r[0]<last_build_id>;

      unless $last_build_id {

        push @projects, %(
          project       => $project,
          last_build_id => "",
          state         => -2, # never started
          dt            => "",
        );
        next;
      }

      $sth = $dbh.prepare("SELECT state, description, dt FROM builds where id = {$last_build_id}");

      $sth.execute();

      @r = $sth.allrows(:array-of-hash);

      $sth.finish;

      my $state = @r[0]<state>;

      my $dt = @r[0]<dt>;

      my $description = @r[0]<description>;

      #my $dt-human = denominate( DateTime.now - DateTime.new("{$dt}")) ~ " ago";

      my $dt-human = "{$dt}";

      push @projects, %(
        http-root     => sparky-http-root(),
        project       => $project,
        last_build_id => $last_build_id,
        state         => $state,
        dt            => $dt-human,
        description   => $description,
      );

    }

    $dbh.dispose;

    template 'templates/projects.crotmp', {

      css => css(), 
      navbar => navbar(), 
      projects => @projects.sort(*.<last_build_id>).reverse,

    }
  
  }
  
  get -> 'builds' {

    my $dbh = get-dbh();

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT * FROM builds order by id desc limit 500
    STATEMENT

    $sth.execute();

    my @rows = $sth.allrows(:array-of-hash);

    $sth.finish;

    $dbh.dispose;
  
     template 'templates/builds.crotmp', {

      css => css(), 
      navbar => navbar(), 
      builds => @rows,

    }
 
  }
  
  get -> 'queue' {
    template 'templates/queue.crotmp', {
      css => css(), 
      navbar => navbar(), 
      builds => find-triggers($root)
    }
  }

  get -> 'badge', $project {

    my $dbh = get-dbh();
    my $sth = $dbh.prepare("SELECT max(id) as last_build_id FROM builds where project = '{$project}'");
    $sth.execute();
    my @r = $sth.allrows(:array-of-hash);
    $sth.finish;
    my $last_build_id =  @r[0]<last_build_id>;
    my $state = -2;

    if ($last_build_id) {
      $sth = $dbh.prepare("SELECT state, description, dt FROM builds where id = {$last_build_id}");
      $sth.execute();
      @r = $sth.allrows(:array-of-hash);
      $sth.finish;
      $state = @r[0]<state>;
    }

    $dbh.dispose;

    given response {
      .append-header('Content-type', 'image/svg+xml;charset=utf-8');
    }

    template 'templates/badge.crotmp', {
      project => $project, 
      state => $state
    }

  }

  get -> 'report', $project, uint32 $build_id  {

    if "$reports-dir/$project/build-$build_id.txt".IO ~~ :f {

      my $dbh = get-dbh();

      my $sth = $dbh.prepare("SELECT state, description, dt, key FROM builds where id = {$build_id}");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      my $state = @r[0]<state>;

      my $dt = @r[0]<dt>;

      my $description = @r[0]<description>;

      my $key = @r[0]<key>;

      $sth.finish;

      $dbh.dispose;

      template 'templates/report.tt', {
        css => css(), 
        navbar => navbar(), 
        project => $project,
        build_id => $build_id, 
        key => $key, 
        dt => $dt, 
        description => $description, 
        data => "$reports-dir/$project/build-$build_id.txt"
      }

    } else {
      not-found();
    }
  
  }


  get -> 'status', $project, $key {

    if trigger-exists($root,$project,$key) {
      -2  # "queued"
    } else {

      my $dbh = get-dbh();

      my $sth = $dbh.prepare("SELECT state, description, dt FROM builds where project = '{$project}' and key = '{$key}'");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      my $state = @r[0]<state>;

      $sth.finish;

      $dbh.dispose;

      if $state.defined {
        $state
      } else {
        not-found();
      }
    }
  }
  
  get -> 'report', 'raw', $project, $key {

    if trigger-exists($root,$project,$key) {
       "build is queued, wait till it gets run"
    } else {

      my $dbh = get-dbh();

      my $sth = $dbh.prepare("SELECT id FROM builds where project = '{$project}' and key = '{$key}'");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      my $build_id = @r[0]<id>;

      $sth.finish;

      $dbh.dispose;

      if $build_id.defined {
        "$reports-dir/$project/build-$build_id.txt".IO.slurp
      } else {
        not-found();
      }
    }

  }

  get -> 'project', $project {
    if "$root/$project/sparrowfile".IO ~~ :f {
      my $project-conf-str; 
      my %project-conf;
      my $error;

      if "$root/$project/sparky.yaml".IO ~~ :f {

        $project-conf-str = "$root/$project/sparky.yaml".IO.slurp; 

        try { %project-conf = load-yaml($project-conf-str) };

        if $! { 

          $error = $!;
 
          say "error parsing $root/$project/sparky.yaml";
          say $error;
        }

      }

      template 'templates/project.crotmp', {
        http-root => sparky-http-root(),
        css =>css(), 
        navbar => navbar(), 
        project => $project, 
        allow-manual-run => %project-conf<allow_manual_run> || False,
        disabled => %project-conf<disabled> || False,
        project-conf-str => $project-conf-str || "configuration not found", 
        scenario-code => "$root/$project/sparrowfile".IO ~~ :e ?? "$root/$project/sparrowfile".IO.slurp !! "scenario not found", 
        error => $error
      }
    } else {
      not-found();
    }
  }
  
  get -> 'about' {
  
    template 'templates/about.crotmp', {
      css => css(), 
      navbar => navbar(), 
      data => "README.md".IO.slurp,
    }

  }

}

my Cro::Service $service = Cro::HTTP::Server.new:
    :host<0.0.0.0>, :port<3000>, :$application;

$service.start;

react whenever signal(SIGINT) {
    $service.stop;
    exit;
}
