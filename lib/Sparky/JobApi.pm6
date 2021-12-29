unit module Sparky::JobApi;

use Sparky;

use HTTP::Tiny;
use JSON::Tiny;
use Sparrow6::DSL;

sub sparky-api () is export {

  my $sparky-api;

  if tags()<SPARKY_WORKER> eq "localhost" {
    $sparky-api = "http://127.0.0.1:{get-sparky-conf()<sparky_port>}";
  } elsif tags()<SPARKY_WORKER> eq "docker" {
    $sparky-api = "http://host.docker.internal:{get-sparky-conf()<sparky_port>}";
  } else {
    die "Sparky::JobApi is not supported for this type of worker: {tags()<SPARKY_WORKER>}"
  }

  return $sparky-api;
}

sub job-queue (%config) is export {

  unless %config<project>  {
    my $workers = %config<workers> || 4;
    my $i = (^$workers).pick(1).join("")+1;
    %config<project> = "{tags()<SPARKY_PROJECT>}.spawned_%.2d".sprintf($i);
  }

  my $rand = ('a' .. 'z').pick(20).join('');

  %config<job-id> ||= "{$rand}{$*PID}";

  %config<parent-project> = tags()<SPARKY_PROJECT>;

  %config<parent-job-id> = tags()<SPARKY_JOB_ID>;

  my %c = config();

  my %upload = %(
    config => %config,
    sparrowfile => $*PROGRAM.IO.slurp,
    sparrowdo-config => %c,
  );

  my $sparky-api = sparky-api();

  say "send request to {$sparky-api}/queue ...";

  my $r = HTTP::Tiny.post: "{$sparky-api}/queue", 
    headers => { content-type => 'application/json' },
    content => to-json(%upload);

  $r<status> == 200 or die $r.perl;

  my %st = from-json($r<content>.decode);

  if %st<error> {
    die %st<error>
  } else {
    return %st
  }

}

sub job-queue-fs (%config,$sparrowfile,$sparrowdo-config) is export {

  my $project = %config<project>;

  my $job-id =  %config<job-id>;

  my $sparky-project-dir = "{%*ENV<HOME>}/.sparky/projects/{$project}";

  mkdir "{$sparky-project-dir}/.triggers" unless "{$sparky-project-dir}/.triggers".IO ~~ :d;

  unless "{$sparky-project-dir}/sparrowfile".IO ~~ :f {
    spurt "{$sparky-project-dir}/sparrowfile", "# dummy file, generated by sparrowdo";
  }

  my $cache-dir = "{%*ENV<HOME>}/.sparky/.cache/$job-id/";

  mkdir $cache-dir;

  "{$cache-dir}/config.pl6".IO.spurt($sparrowdo-config.perl);

  my %trigger = EVALFILE("{%*ENV<HOME>}/.sparky/work/{%config<parent-project>}/.triggers/{%config<parent-job-id>}");

  %trigger<cwd> = $cache-dir;

  # override parent job sparrowdo configuration
  # by %config<sparrowdo>

  %trigger<sparrowdo> ||= {};

  if %config<sparrowdo> {
    for %config<sparrowdo>.keys -> $k {
      %trigger<sparrowdo>{$k} = %config<sparrowdo>{$k};
    }
    # handle conflicting parameters
    if %config<sparrowdo><localhost> {
      %trigger<sparrowdo><docker>:delete;
      %trigger<sparrowdo><host>:delete;
    } elsif %config<sparrowdo><host> {
      %trigger<sparrowdo><docker>:delete;
      %trigger<sparrowdo><localhost>:delete;
    } elsif %config<sparrowdo><docker> {
      %trigger<sparrowdo><host>:delete;
      %trigger<sparrowdo><localhost>:delete;
    }
    if %config<sparrowdo><sudo> {
      %trigger<sparrowdo><no_sudo>:delete;
    }
  }


  %trigger<description> = %config<description> || "spawned job";

  # override sparrowdo tags by %config<tags>

  %trigger<sparrowdo><tags> = %config<tags>.map({"{$_.key}={$_.value}"}).join(",") if %config<tags>;

  %trigger<sparrowdo><conf> = "config.pl6";

  say "job-queue-fs: create trigger file: {$sparky-project-dir}/.triggers/$job-id";

  "{$sparky-project-dir}/.triggers/$job-id".IO.spurt(%trigger.perl);

  "{$cache-dir}/sparrowfile".IO.spurt($sparrowfile);

  return  { project => $project, job-id => $job-id };

}


