systemd-service "sparky-web", %(
  user => "scheck",
  workdir => "/home/scheck/projects/sparky",
  command => "/usr/bin/bash --login -c 'cd /home/scheck/projects/sparky && export SPARKY_HTTP_ROOT=/sparky && export SPARKY_ROOT=/home/scheck/.sparky/projects && export BAILADOR=host:127.0.0.1,port:8000 && export SPARKY_ROOT=/home/scheck/projects/RakuDist/sparky/ && perl6 bin/sparky-web.pl6 1>~/.sparky-web.log 2>&1'"
);

# start service

service-restart "sparky-web";

