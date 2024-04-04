use Cro::HTTP::Server;
use Cro::HTTP::Router;
use Cro::HTTP::Client;
use Cro::WebApp::Template;
use Cro::HTTP::Auth::Basic;
use Cro::HTTP::Router::WebSocket;
use Cro::WebSocket::Message;

use DBIish;
use Sparky;
use Sparky::Security;
use Sparky::HTML;
use Sparky::Utils;
use YAMLish;
use Text::Markdown;
use Sparky::Job;
use JSON::Fast;
use DBIish::Pool;

my $root = %*ENV<SPARKY_ROOT> || %*ENV<HOME> ~ '/.sparky/projects';

my $reports-dir = "$root/.reports";

sub create-cro-app ($pool) {

  my $application = route { 

  get -> 'livereport', $project, $build_id, $key {
    web-socket -> $incoming {
        supply {
            my $last_e = 0;
            whenever $incoming -> $message {
                my $done = False;
                my @chunk;
                my $i = 0;
                while True  {
                  my @data = "$reports-dir/$project/build-$build_id.txt".IO.lines;
                  for @data[$last_e .. *] -> $l {
                    my $msg = "{$l}";
                    if sparky-api-token() {
                      $msg.=subst(sparky-api-token(),"*******",:g);
                    }
                    @chunk.push($msg);
                    #emit($msg);
                  }
                  $i++; sleep(1);
                  if @chunk.elems > 0 and (@chunk.elems >= 1000 or $i <= 10) {
                    say("ws: send data to client: {@chunk.elems} lines");
                    emit(@chunk.join("\n"));
                    @chunk = ();
                  }
                  $last_e = @data.elems;
                  #if trigger-exists($root,$project,$key) {
                    #$done = True;
                  #  say "ws: job in queue";
                    #last(); 
                  #} elsif job-state-exists($root,$project,$key) && 
                  #  ( 
                  #    job-state($root,$project,$key) == -1 or 
                  #    job-state($root,$project,$key) == 1 
                  #  ) { 
                  # get state from file cache if cache exists
                  #  say "ws: done - job has finished (cache state): {job-state($root,$project,$key)}";
                  #  $done = True;
                  #  last();
                    #content 'text/plain', "{job-state($root,$project,$key)}"
                  #} else {
      
                    my $dbh = $pool ?? $pool.get-connection() !! get-dbh();
  
                    my $sth = $dbh.prepare("SELECT state, description, dt FROM builds where project = '{$project}' and job_id = '{$key}'");

                    $sth.execute();

                    my @r = $sth.allrows(:array-of-hash);

                    my $state = @r[0]<state>;

                    $sth.finish;

                    $dbh.dispose;

                  if $state.defined {
                    if $state == -1 or $state == 1 {
                      say "ws: done - job has finsihed - state: [$state]";
                      $done = True;
                      last();
                    }
                  } else {
                    say "ws: done - job not found";
                    $done = True;
                    last();
                  }
                }

                my @data = "$reports-dir/$project/build-$build_id.txt".IO.lines;
                for @data[$last_e .. *] -> $l {
                  my $msg = "{$l}";
                  if sparky-api-token() {
                    $msg.=subst(sparky-api-token(),"*******",:g);
                  }
                  @chunk.push($msg);
                }

                if @chunk.elems > 0 {
                  emit(@chunk.join("\n"));
                  @chunk = ();
                }

                if $done {
                  emit "---";
                  done 
                }
            }
        }
    }
  }

  post -> 'build', 'project', $project, :$user is cookie, :$token is cookie {
    
    if check-user($user, $token, $project) {
      my $id = "{('a' .. 'z').pick(20).join('')}.{$*PID}";

      my %trigger = %(
        description =>  "triggered by user $user",
      );

      mkdir "$root/$project/.triggers";

      spurt "$root/$project/.triggers/$id", %trigger.perl;

      content 'text/plain', "$id";

    } else {

      forbidden 

    }

  }

  post -> 'build-with-tags', 'project', $project, :$user is cookie, :$token is cookie {

    if check-user($user, $token, $project) {

      my $id = "{('a' .. 'z').pick(20).join('')}.{$*PID}";

      request-body  -> (:$tags?, :$description?) {

        mkdir "$root/$project/.triggers";

        my %trigger = %(
          description => $description || "triggered by user $user",
          sparrowdo => %(
            tags => $tags || "",
          ),
        );
        spurt "$root/$project/.triggers/$id", %trigger.perl;

      }

      content 'text/plain', "$id";

    } else {

      forbidden;

    }

  }

  post -> 'build', 'project', $project, $key, :$user is cookie, :$token is cookie {

    if check-user($user, $token, $project) {

      if "$root/$project/sparky.yaml".IO ~~ :e or sparky-allow-rebuild-spawn() {

        mkdir "$root/$project/.triggers";

        my $postfix = "{('a' .. 'z').pick(10).join('')}.{$*PID}";

        copy "$root/../work/$project/.triggers/$key", "$root/$project/.triggers/{$key}.{$postfix}";

        content 'text/plain', "{$key}.{$postfix}";

      } else {

        bad-request 'text/plain', 'rebuilding for project without sparky.yaml is forbidden';

      }

    } else {
      forbidden;
    }
    
  }

  #
  # SparkyJobApi methods
  #

  post -> 'queue', :$token? is header {

    if sparky-api-token() and ( ! $token || (sparky-api-token() ne $token) ) {

      forbidden("text/plain","bad token");

    } else {

      my $res;

      request-body -> %json {

        try { 

          $res = job-queue-fs(%json<config>,%json<trigger>,%json<sparrowfile>,%json<sparrowdo-config>);

          CATCH {
            default {
              my $err = "Error {.^name}, : , {.Str}";
              $res = to-json({ error => $err });
            }
          }
        }

      }

      content 'application/json', $res;

    }

  }

  post -> 'stash', :$token? is header  {

    if sparky-api-token() and ( ! $token || (sparky-api-token() ne $token) ) {

      forbidden("text/plain","bad token");

    } else {

      my $res;

      request-body -> %json {

        try { 

          $res = put-job-stash(%json<config>,%json<data>);

          CATCH {
            default {
              my $err = "Error {.^name}, : , {.Str}";
              $res = to-json({ error => $err });
            }
          }
        }

      }

      content 'application/json', $res;

    }

  }

  get -> 'stash', $project, $key   {

      content 'application/json', get-job-stash($project,$key);

  }

  put -> 'file', 'project', $project, 'job', $job-id, 'filename', $filename, :$token? is header  {

    if sparky-api-token() and ( ! $token || (sparky-api-token() ne $token) ) {

      forbidden("text/plain","bad token");

    } else {

      my $res;

      request-body-blob  -> $data {

        try { 

          $res = put-job-file($project,$job-id,$filename,$data);

          CATCH {
            default {
              my $err = "Error {.^name}, : , {.Str}";
              $res = to-json({ error => $err });
            }
          }
        }

      }

      content 'application/json', $res;

    }

  }

  get -> 'file', $project, $key, $filepath  {

      if get-job-file($project,$key,$filepath).IO ~~ :f {
        content 'application/octet-stream', slurp(get-job-file($project,$key,$filepath),:bin);
      } else {
        not-found()
      } 
  }

  #
  # End of SparkyJobApi methods
  #

  get -> 'set-theme', :$theme {

    my $date = DateTime.now.later(years => 100);

    set-cookie 'theme', $theme, http-only => True, expires => $date;

    redirect :see-other, "{sparky-http-root()}/?message=theme changed&level=info";

  }

  get -> "", :$message, :$level, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
  
    my @projects = Array.new;

    my $dbh = $pool ?? $pool.get-connection() !! get-dbh();

    for dir($root) -> $dir {

      next if "$dir".IO ~~ :f;
      next if $dir.basename eq '.git';
      next if $dir.basename eq '.reports';
      next if $dir.basename eq 'db.sqlite3-journal';
      next unless "$dir/sparrowfile".IO ~~ :f;
      next unless "$dir/sparky.yaml".IO ~~ :f;

      my $project = $dir.IO.basename;

      my $sth = $dbh.prepare("SELECT max(id) as last_build_id FROM builds where project = '{$project}'");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      $sth.finish;

      my $last_build_id =  @r[0]<last_build_id>;

      unless $last_build_id {

        push @projects, %(
          project       => $project,
          state         => -2, # never started
          dt            => "N/A",
          last_build_id => "",
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

      my $dt-human = $dt;

      push @projects, %(
        project       => $project,
        last_build_id => $last_build_id,
        state         => $state,
        dt            => $dt-human,
        description   => $description,
      );

    }

    $dbh.dispose;

    my @q = find-triggers($root);
    my $st = qx[uptime].chomp.subst(/.* "load"/,"load");
    my $core = qx[nproc --all].chomp;

    template 'templates/projects.crotmp', {
      state => $st,
      core => $core,
      queue => @q.elems,
      user => $user,
      http-root => sparky-http-root(),
      css => css($theme), 
      navbar => navbar($user, $token), 
      projects => @projects.sort(*.<project>),
      theme => "$theme",
      message => "$message",
      level => "$level",
    }
  
  }
  
  get -> 'builds', :$theme is cookie = default-theme(), :$user is cookie, :$token is cookie {

    my $dbh = $pool ?? $pool.get-connection() !! get-dbh();

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT * FROM builds order by id desc limit 500
    STATEMENT

    $sth.execute();

    my @rows = $sth.allrows(:array-of-hash);

    $sth.finish;

    $dbh.dispose;

    #say @rows.perl;
  
    template 'templates/builds.crotmp', {

      css => css($theme), 
      navbar => navbar($user,$token),
      http-root => sparky-http-root(),
      builds => @rows,

    }
 
  }
  
  get -> 'queue', :$theme is cookie = default-theme(), :$user is cookie, :$token is cookie {
    template 'templates/queue.crotmp', {
      css => css($theme), 
      navbar => navbar($user,$token), 
      builds => find-triggers($root)
    }
  }

  get -> 'livequeue', :$theme is cookie = default-theme() {

    web-socket -> $incoming {
      supply {
        whenever $incoming -> $message {
          my $done = False;
          while True {
            my @q = find-triggers($root);
            my $st = qx[uptime].chomp.subst(/.* "load"/,"load");
            my $core = qx[nproc --all].chomp;
            emit "$st | $core cpu cores | {@q.elems} builds in queue | theme: {$theme}";
            sleep(10);
          }
          if $done {
            done
          }     
        }
      }
    }
  }

  get -> 'badge', $project {

    my $dbh = $pool ?? $pool.get-connection() !! get-dbh();

    my $sth = $dbh.prepare("SELECT max(id) as last_build_id FROM builds where project = '{$project}'");
    $sth.execute();
    my @r = $sth.allrows(:array-of-hash);
    $sth.finish;
    my $last_build_id =  @r[0]<last_build_id>;
    my $state = -2;

    if ($last_build_id) {
      $sth = $dbh.prepare("SELECT state FROM builds where id = {$last_build_id}");
      $sth.execute();
      @r = $sth.allrows(:array-of-hash);
      $sth.finish;
      $state = @r[0]<state>;
    }

    $dbh.dispose;

    if $state == -1 {
      redirect :permanent, '/icons/build-fail.png';
    }

    if $state == 1 {
      redirect :permanent, '/icons/build-pass.png';
    }

    if $state == 0 {
      redirect :permanent, '/icons/build-run.png';
    }

    if $state == -2 {
      redirect :permanent, '/icons/build-na.png';
    }

  }

  get -> 'icons', *@path {

    cache-control :public, :max-age(3000);

    static 'icons', @path;

  }

  get -> 'report', $project, $build_id, :$theme is cookie = default-theme(),:$user is cookie, :$token is cookie {

    if "$reports-dir/$project/build-$build_id.txt".IO ~~ :f {

      my $dbh = $pool ?? $pool.get-connection() !! get-dbh();

      my $sth = $dbh.prepare("SELECT state, description, dt, job_id FROM builds where id = {$build_id}");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      my $state = @r[0]<state>;

      my $dt = @r[0]<dt>;

      my $description = @r[0]<description>;

      my $key = @r[0]<job_id>;

      $sth.finish;

      $dbh.dispose;

      my $data = "$reports-dir/$project/build-$build_id.txt".IO.slurp;

      if sparky-api-token() {

        $data.=subst(sparky-api-token(),"*******",:g);
      
      }

      template 'templates/report2.crotmp', {
        css => css($theme), 
        navbar => navbar($user,$token), 
        http-root => sparky-http-root(),
        sparky-tcp-port => sparky-tcp-port(),
        project => $project,
        build_id => $build_id,
        job_id => "{$key}", 
        dt => $dt, 
        description => $description, 
        data => $data
      }

    } else {
      not-found();
    }
  
  }

  get -> 'status', $project, $key {

    if trigger-exists($root,$project,$key) {
      content 'text/plain', "-2" 
    } elsif job-state-exists($root,$project,$key) { 
      # get state from file cache if cache exists
      content 'text/plain', "{job-state($root,$project,$key)}"
    } else {
      my $dbh = $pool ?? $pool.get-connection() !! get-dbh();
  
      my $sth = $dbh.prepare("SELECT state, description, dt FROM builds where project = '{$project}' and job_id = '{$key}'");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      my $state = @r[0]<state>;

      $sth.finish;

      $dbh.dispose;

      if $state.defined {
        content 'text/plain', "$state"
      } else {
        not-found();
      }
    }
  }
  
  get -> 'livestatus', $project, $key {

    web-socket -> $incoming {
      supply {
        whenever $incoming -> $message {
          my $done = False;
          while True {
            if trigger-exists($root,$project,$key) {
              emit "[{DateTime.now(formatter => { sprintf "%02d:%02d:%02d", .hour, .minute, .second })}] - build in queue";
              sleep(1);
            } else {
                my $dbh = $pool ?? $pool.get-connection() !! get-dbh();
                my $sth = $dbh.prepare("SELECT state, id FROM builds where project = '{$project}' and job_id = '{$key}'");
                $sth.execute();
                my @r = $sth.allrows(:array-of-hash);
                my $build_id = @r[0]<id>;
                $sth.finish;
                $dbh.dispose;
                if $build_id {
                  say "ws - build has started, build_id: {$build_id}";
                  emit "[{DateTime.now(formatter => { sprintf "%02d:%02d:%02d", .hour, .minute, .second })}] - \&nbsp; <a href=\"{sparky-http-root()}/report/{$project}/{$build_id}\">build_id: {$build_id} has started</a>";
                  $done = True;
                  last();
                }
            }
          }
          if $done {
            # emit "[{DateTime.now(formatter => { sprintf "%02d:%02d:%02d", .hour, .minute, .second })}] ---";
            done 
          }          
        }
      }
    }
  }

  get -> 'report', 'raw', $project, $key {

    if trigger-exists($root,$project,$key) {
       content 'text/plain', "build is queued, wait till it gets run\n"
    } else {

      my $dbh = $pool ?? $pool.get-connection() !! get-dbh();

      my $sth = $dbh.prepare("SELECT id FROM builds where project = '{$project}' and job_id = '{$key}'");

      $sth.execute();

      my @r = $sth.allrows(:array-of-hash);

      my $build_id = @r[0]<id>;

      $sth.finish;

      $dbh.dispose;

      if $build_id.defined {

        my $data = "$reports-dir/$project/build-$build_id.txt".IO.slurp;

        if sparky-api-token() {

          $data.=subst(sparky-api-token(),"*******",:g);
      
        }
        content 'text/plain', $data;
      } else {
        not-found();
      }
    }

  }

  get -> 'trigger', $project, $key, :$token? is header {

    if sparky-api-token() and ( ! $token || (sparky-api-token() ne $token) ) {

      forbidden("text/plain","bad token");
  
    } elsif "$root/$project/.triggers/$key".IO ~~ :f  {

        my $data = "$root/$project/.triggers/$key".IO.slurp;

        content 'text/plain', $data;

    } elsif "$root/../work/$project/.triggers/$key".IO ~~ :f  {

        my $data = "$root/../work/$project/.triggers/$key".IO.slurp;

        content 'text/plain', $data;

     } else {
       not-found();
    }

  }

  get -> 'project', $project, :$theme is cookie = default-theme(), :$user is cookie, :$token is cookie {
    if "$root/$project/sparrowfile".IO ~~ :f {
      my $project-conf-str; 
      my %project-conf;
      my $error;

      if "$root/$project/sparky.yaml".IO ~~ :f {

        $project-conf-str = "$root/$project/sparky.yaml".IO.slurp; 

        try { %project-conf = load-yaml($project-conf-str) };

        if $! { 
          $error = $!;
          say "project/$project: error parsing $root/$project/sparky.yaml";
          say $error;
        }

      }

      template 'templates/project.crotmp', {
        http-root => sparky-http-root(),
        css =>css($theme), 
        navbar => navbar($user, $token), 
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

  get -> 'build', 'project', $project, :$theme is cookie = default-theme(), :$user is cookie, :$token is cookie  {

    if check-user($user, $token, $project) {

      my %project-conf = %();
      my %shared-vars = %();
      my %host-vars = %();

      if "$root/$project/sparrowfile".IO ~~ :f {
        my $project-conf-str; 
        my %project-conf;
        my $error;

        if "$root/$project/sparky.yaml".IO ~~ :f {

          say "project/$project: load sparky.yaml";
          $project-conf-str = "$root/$project/sparky.yaml".IO.slurp; 

          try { %project-conf = load-yaml($project-conf-str) };

          if $! {
            $error = $!;
            say "project/$project: error parsing $root/$project/sparky.yaml";
            say $error;
          }

        }

        if "$root/../templates/vars.yaml".IO ~~ :f {

          say "templates: load shared vars from vars.yaml";

          try { %shared-vars = load-yaml("$root/../templates/vars.yaml".IO.slurp) };

          if $! {
            $error ~= $!;
            say "project/$project: error parsing $root/../templates/var.yaml";
            say $error;
          }

        }

        if "$root/../templates/hosts/{hostname()}/vars.yaml".IO ~~ :f {

          say "templates: load host vars from {hostname()}/vars.yaml";

          try { %host-vars = load-yaml("$root/../templates/hosts/{hostname()}/vars.yaml".IO.slurp) };

          if $! {
            $error ~= $!;
            say "project/$project: error parsing $root/../templates/hosts/{hostname()}/vars.yaml";
            say $error;
          }

        }

        for (%project-conf<vars><> || []) -> $v {
        if $v<default> {
          for $v<default> ~~ m:global/"%" (\S+?) "%"/ -> $c {
            my $var_id = $c[0].Str;
            # apply vars from host vars first
            my $host-var = get-template-var(%host-vars<vars>,$var_id);
            if defined($host-var) {
              if $host-var.isa(Str) or $host-var.isa(Rat) or $host-var.isa(Int) {
                $v<default>.=subst("%{$var_id}%",$host-var,:g);
              } else {
                $v<default> = $host-var;
              }
              say "project/$project: default - insert default %{$var_id}% from host vars";
              next;
            }
            my $shared-var = get-template-var(%shared-vars<vars>,$var_id);
            if defined($shared-var) {
              if $shared-var.isa(Str) or $shared-var.isa(Rat) or $shared-var.isa(Int) {
                $v<default>.=subst("%{$var_id}%",$shared-var,:g);
              } else {
                $v<default> = $shared-var;
              }
              say "project/$project: default - insert default %{$var_id}% from shared vars";
            }
          }
        }
        if $v<value> && $v<value>.isa(Str) {
          for $v<value> ~~ m:global/"%" (\S+?) "%"/ -> $c {
            my $var_id = $c[0].Str;
            # apply vars from host vars first
            my $host-var = get-template-var(%host-vars<vars>,$var_id);
            if defined($host-var) {
              if $host-var.isa(Str) or $host-var.isa(Rat) or $host-var.isa(Int)  {
                $v<value>.=subst("%{$var_id}%",$host-var,:g);
              } else {
                $v<value> = $host-var;
              }
              say "project/$project: value - insert value %{$var_id}% from host vars";
              next;
            }
            my $shared-var = get-template-var(%shared-vars<vars>,$var_id);
            if defined($shared-var) {
            if $shared-var.isa(Str) or $shared-var.isa(Rat) or $shared-var.isa(Int)  {
              $v<value>.=subst("%{$var_id}%",$shared-var,:g);
            } else {
              $v<value> = $shared-var;
            }
            say "project/$project: value - insert value %{$var_id}% from shared vars";
            }
          }
        }
        if $v<values> && $v<values>.isa(Str)   {
          for $v<values> ~~ m:global/"%" (\S+?) "%"/ -> $c {
            my $var_id = $c[0].Str;
            # apply vars from host vars first
            my $host-var = get-template-var(%host-vars<vars>,$var_id);
            if defined($host-var) {
              if $host-var.isa(Str) or $host-var.isa(Rat) or $host-var.isa(Int) {
                $v<values>.=subst("%{$var_id}%",$host-var,:g);
              } else {
                $v<values> = $host-var.isa(List) ?? $host-var.sort !! $host-var;
              }
              say "project/$project: values - insert values %{$var_id}% from host vars";
              next;
            }
            my $shared-var = get-template-var(%shared-vars<vars>,$var_id);
            if defined($shared-var) {
              if $shared-var.isa(Str) or $shared-var.isa(Rat) or $shared-var.isa(Int) {
                $v<values>.=subst("%{$var_id}%",$shared-var,:g);
              } else {
                $v<values> = $shared-var.isa(List) ?? $shared-var.sort !! $shared-var;
              }
              say "project/$project: values - insert values %{$var_id}% from shared vars";
            }
          }
        }
        }

        template 'templates/build.crotmp', {
          http-root => sparky-http-root(),
          sparky-tcp-port => sparky-tcp-port(),
          css =>css($theme), 
          navbar => navbar($user, $token), 
          project => $project, 
          allow-manual-run => %project-conf<allow_manual_run> || False,
          disabled => %project-conf<disabled> || False,
          project-conf-str => $project-conf-str || "configuration not found",
          project-conf => %project-conf || {},
          vars => %project-conf<vars> || [],
          scenario-code => "$root/$project/sparrowfile".IO ~~ :e ?? "$root/$project/sparrowfile".IO.slurp !! "scenario not found", 
          error => $error
        }
      } else {
        not-found();
      }

    } else {

      redirect :see-other, "{sparky-http-root()}/?message=unauthorized&level=error";

    }

  }
  
  get -> 'about', :$theme is cookie = default-theme() {
  
    template 'templates/about.crotmp', {
      css => css($theme), 
      navbar => navbar(), 
      data => parse-markdown("README.md".IO.slurp).to_html,
    }

  }

  #
  # Authentication methods
  #
  
  get -> 'login' {
    say "auth: request user identity using {get-sparky-conf()<auth><provider_url>}/authorize ...";
    redirect :see-other,
      "{get-sparky-conf()<auth><provider_url>}/authorize?" ~
      "client_id={get-sparky-conf()<auth><client_id>}&" ~
      "redirect_uri={get-sparky-conf()<auth><redirect_url>}&" ~
      "response_type=code&" ~
      "scope={get-sparky-conf()<auth><scope>}&" ~
      "state={get-sparky-conf()<auth><state>}&"
  }

  get -> 'logout', :$user is cookie, :$token is cookie {

    set-cookie 'user', Nil;
    set-cookie 'token', Nil;

    if ( $user && $token && "{cache-root()}/users/{$user}/tokens/{$token}".IO ~~ :e ) {

      unlink "{cache-root()}/users/{$user}/tokens/{$token}";
      say "unlink user token - {cache-root()}/users/{$user}/tokens/{$token}";

      if ( $user && $token && "{cache-root()}/users/{$user}/meta.json".IO ~~ :e ) {

        unlink "{cache-root()}/users/{$user}/meta.json";
        say "unlink user meta - {cache-root()}/users/{$user}/meta.json";

      }

    }
    redirect :see-other, "{sparky-http-root()}/?message=user logged out&level=info";

  } 

  # see https://www.hibit.dev/posts/53/gitlab-oauth20-access-for-web-application

  get -> 'oauth2', :$state, :$code {

      say "auth: request oauth token using {get-sparky-conf()<auth><provider_url>}/token ...";
      say "auth: state: $state code $code";
      # die "";

      my $id_tmp = "{('a' .. 'z').pick(20).join('')}.{$*PID}";

      shell qq:to /CURL/;
      set -x
      curl -X POST {get-sparky-conf()<auth><provider_url>}/token \\
      -d client_id={get-sparky-conf()<auth><client_id>} \\
      -d client_secret={get-sparky-conf()<auth><client_secret>} \\
      -d code=$code \\
      -d grant_type=authorization_code \\
      -d redirect_uri={get-sparky-conf()<auth><redirect_url>} \\
      -f -L -s -o {cache-root()}/users/token_{$id_tmp}.json
      CURL

      my $data = "{cache-root()}/users/token_{$id_tmp}.json".IO.slurp;

      my %data = from-json($data);

      unlink "{cache-root()}/users/token_{$id_tmp}.json";

      #say "response recieved - {%data.perl} ... ";

      if %data<access_token>:exists {

        say "auth: token recieved - {%data<access_token>} ... ";

        say "auth: request user data using {get-sparky-conf()<auth><user_api>} ...";

        $id_tmp = "{('a' .. 'z').pick(20).join('')}.{$*PID}";

        shell qq:to /CURL/;
        curl -H "Authorization: Bearer {%data<access_token>}" \\
        {get-sparky-conf()<auth><user_api>} \\
        -f -L -s -o {cache-root()}/users/user_{$id_tmp}.json
        CURL

        my $data2 = "{cache-root()}/users/user_{$id_tmp}.json".IO.slurp;

        say "auth: use data recieved - {$data2}";
  
        my %data2 = from-json($data2);

        unlink "{cache-root()}/users/user_{$id_tmp}.json";

        say "auth: {%data2.perl}";

        %data2<login> = %data2<username>;

        say "set user login to {%data2<username>}";

        my $date = DateTime.now.later(years => 100);

        set-cookie 'user', %data2<login>, http-only => True, expires => $date;

        set-cookie 'token', user-create-account(%data2<login>,%data2), http-only => True, expires => $date;

        redirect :see-other, "{sparky-http-root()}/?message=user [{%data2<name>}] logged in&level=info";

      } else {

        redirect :see-other, "{sparky-http-root()}/?message=issues with login&level=info";

      }
      
  }

  #
  # End of Authentication methods
  #

  #
  # Static files methods
  #

  get -> 'js', *@path {
    cache-control :public, :max-age(300);
    static 'js', @path;
  }

  get -> 'css', *@path {
    cache-control :public, :max-age(10);
    static 'css', @path;
  }

  #
  # End of Static files methods
  #

}

}

my $pool;

if get-database-engine() ne "sqlite" {

    my %conf = get-sparky-conf();
    my %connection-parameters = 
        host      => %conf<database><host>,
        port      => %conf<database><port>,
        database  => %conf<database><name>,
        user      => %conf<database><user>,
        password  => %conf<database><pass>;

    my $pool = DBIish::Pool.new(
      driver => get-database-engine(), 
      max-connections => 50, 
      max-idle-duration => Duration.new(60),
      min-spare-connections => 3,  
      initial-size => 5, 
      |%connection-parameters
    );

}

my $application = create-cro-app($pool);

(.out-buffer = False for $*OUT, $*ERR;);

my $port = sparky-tcp-port();

my $host = sparky-host();

say "run sparky web ui on host: {$host}, port: {$port} ...";

my Cro::Service $service;

if sparky-use-tls() {

  say "use tls mode ...";

  my %tls = sparky-tls-settings();

  say "load tls settings: ", %tls.perl;

  $service = Cro::HTTP::Server.new: :$host, :$port, :$application, :%tls;

} else {

  $service = Cro::HTTP::Server.new: :$host, :$port, :$application;
}

$service.start;

react whenever signal(SIGINT) {
    $service.stop;
    exit;
}
