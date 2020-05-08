use Bailador;
use DBIish;
use Text::Markdown;
use Sparky;
use YAMLish;
use Number::Denominate;

my $root = %*ENV<SPARKY_ROOT> || %*ENV<HOME> ~ '/.sparky/projects';
my $reports-dir = "$root/.reports";

#say $root;

static-dir / (.*) / => '/public';

post '/build/project/:project' => sub ($project) {

  my $id = "{('a' .. 'z').pick(20).join('')}{$*PID}";

  mkdir "$root/$project/.triggers";

  spurt "$root/$project/.triggers/$id", "%( 
    description => 'triggered by user',
  )";

  schedule-build "$root/$project";

  "triggered by user";
}

get '/' => sub {

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
      project       => $project,
      last_build_id => $last_build_id,
      state         => $state,
      dt            => $dt-human,
      description   => $description,
    );

  }

  $dbh.dispose;

  template 'projects.tt', css(), navbar(), @projects.sort(*.<last_build_id>).reverse;

}

get '/builds' => sub {

  my $dbh = get-dbh();

  my $sth = $dbh.prepare(q:to/STATEMENT/);
      SELECT * FROM builds order by id desc limit 500
  STATEMENT

  $sth.execute();

  my @rows = $sth.allrows(:array-of-hash);

  $sth.finish;

  $dbh.dispose;


  template 'builds.tt', css(), navbar(), @rows;

}

get '/queue' => sub {

  template 'queue.tt', css(), navbar(), find-triggers($root);

}

get '/report/:project/:build_id' => sub ( $project, $build_id ) {

  if "$reports-dir/$project/build-$build_id.txt".IO ~~ :f {

    my $dbh = get-dbh();

    my $sth = $dbh.prepare("SELECT state, description, dt FROM builds where id = {$build_id}");

    $sth.execute();

    my @r = $sth.allrows(:array-of-hash);

    my $state = @r[0]<state>;

    my $dt = @r[0]<dt>;

    my $description = @r[0]<description>;

    $sth.finish;

    $dbh.dispose;

    template 'report.tt', css(), navbar(), $project, $build_id, $dt, $description, "$reports-dir/$project/build-$build_id.txt";

  } else {
    status(404);
  }

}

get '/status/:project/:key' => sub ( $project, $key ) {

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
      return $state
    } else {
      status(404);
    }
  }
}

get '/report/raw/:project/:key' => sub ( $project, $key ) {

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
      return "$reports-dir/$project/build-$build_id.txt".IO.slurp
    } else {
      status(404);
    }
  }

}

get '/project/:project' => sub ($project) {
  if "$root/$project/sparrowfile".IO ~~ :f {
    my $project-conf;
    my $err;
      if "$root/$project/sparky.yaml".IO ~~ :f {
      $project-conf = slurp "$root/$project/sparky.yaml";
      load-yaml($project-conf);
      CATCH {
        default {
          $err = .Str;
        }
      }
    }
    template 'project.tt', css(), navbar(), $project, $project-conf, "$root/$project/sparrowfile", $err;
  } else {
    status(404);
  }
}

get '/about' => sub {

  my $raw-md = slurp "README.md";
  my $md = parse-markdown($raw-md);
  template 'about.tt', css(), navbar(), $md.to_html;
}


sub css {

  my %conf = get-sparky-conf();

  my $theme ;

  if %conf<ui> && %conf<ui><theme> {
    $theme = %conf<ui><theme>
  } else {
    $theme = "cosmo";
  }

  qq:to /HERE/

  <meta charset="utf-8">

  <link rel="stylesheet" href="https://unpkg.com/bulmaswatch/$theme/bulmaswatch.min.css">

  HERE

}

sub navbar {

  qq:to /HERE/


    <nav class="navbar" role="navigation" aria-label="main navigation">
      <div class="navbar-brand">
        <a role="button" class="navbar-burger burger" aria-label="menu" aria-expanded="false" data-target="navbarBasicExample">
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
        </a>
      </div>

      <div id="navbarBasicExample" class="navbar-menu">
        <div class="navbar-start">
          <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/">
            Projects
          </a>

          <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/builds">
            Recent Builds
          </a>

          <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/queue">
            Queue
          </a>

          <div class="navbar-item has-dropdown is-hoverable">
            <a class="navbar-link">
              More
            </a>

            <div class="navbar-dropdown">
              <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/about">
                About
              </a>
              <a class="navbar-item" href="https://github.com/melezhik/sparky">
                Docs
              </a>
              <a class="navbar-item" href="https://github.com/melezhik/sparky/issues">
                Report an issue
              </a>
            </div>
          </div>
        </div>
      </div>
    </nav>

  HERE

}

baile;
