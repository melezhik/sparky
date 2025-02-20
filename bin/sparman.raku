sub MAIN(
  Str   $comp,
  Str   $action,
  Bool  :$verbose? = False,
  Str   :$base?,
  Str   :$env?,
) {

    say "Execute $action on $comp ...";

    die "unknown component" unless $comp  ~~ /^^ (worker|worker_ui) $$/;

    my $c = _get_conf();
    my $vars = $env ?? $env.split(/","/).map({"export $_"}).join("\n") !! "";

    if $comp eq "worker_ui" {
      if ! $c<worker><base> and $action eq "start" {
        say "worker ui base dir not found, tell me where to look it up:";
        say "sparman.raku --base /path/to/basedir worker_ui conf";
        exit(1)
      }
      if $action eq "start" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep "raku bin/sparky-web.raku"|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then ] ~
            qq[\ncd {$c<worker><base>}\n] ~
            q[mkdir -p ~/.sparky ] ~
            qq[\n$vars\n] ~
            q[nohup raku bin/sparky-web.raku 1>~/.sparky/sparky-web.log 2>&1 < /dev/null &
            echo "run [OK]"
          else
            echo "already running pid=$pid ..."
          fi
        ];          
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "stop" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep "raku bin/sparky-web.raku"|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "already stopped"
          else
            echo "kill $pid ..."
            kill $pid
            echo "stop [OK] | pid=$pid"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "conf" {
        if $base {
          $c<worker><base> = $base;
          _update_conf($c);
        }
      } elsif $action eq "status" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep "raku bin/sparky-web.raku"|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "stop [OK]"
          else
            echo "run [OK] | pid=$pid"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      } else {
        die "unknown action"
      }
    } 
    if $comp eq "worker" {
      if $action eq "start" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            mkdir -p ~/.sparky/] ~
            qq[\n$vars\n] ~
            q[nohup sparkyd 1>~/.sparky/sparkyd.log 2>&1 < /dev/null &
            echo "run [OK]"
          else
            echo "already running pid=$pid ..."
          fi
        ];          
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "stop" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "already stopped"
          else
            echo "kill $pid ..."
            kill $pid
            echo "stop [OK] | pid=$pid"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "status" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "stop [OK]"
          else
            echo "run [OK] | pid=$pid"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      } else {
        die "unknown action"
      }
    }

}

sub _get_conf {
  if "{%*ENV<HOME>}/.sparky/conf.raku".IO ~~ :e {
    EVALFILE "{%*ENV<HOME>}/.sparky/conf.raku"
  } else {
    return {}
  }
}

sub _update_conf (%c) {
  mkdir "{%*ENV<HOME>}/.sparky/";
  say "update {%*ENV<HOME>}/.sparky/conf.raku ...";
  "{%*ENV<HOME>}/.sparky/conf.raku".IO.spurt(%c.perl)
}
