systemd-service "sparky-web-example", %(
  user => "scheck",
  workdir => "/home/scheck/projects/sparky",
  command => "/usr/bin/bash --login -c 'cd /home/scheck/projects/sparky && export SPARKY_ROOT=/home/scheck/.sparky/projects && export BAILADOR=host:127.0.0.1,port:8000 && perl6 bin/sparky-web.pl6'"
);

# start service

service-restart "sparky-web-example";

