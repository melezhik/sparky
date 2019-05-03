systemd-service "sparky-web-example", %(
  user => "root",
  workdir => "/root/projects/sparky",
  command => "/usr/bin/bash --login -c 'cd /root/projects/sparky && export SPARKY_ROOT=/root/projects/sparky/examples && export BAILADOR=host:0.0.0.0,port:90 && perl6 bin/sparky-web.pl6'"
);

# start service

service-restart "sparky-web-example";

