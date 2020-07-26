my $user = "melezhik";

systemd-service "sparky-web", %(
  user => $user,
  workdir => "/home/$user/projects/sparky",
  command => "/usr/bin/bash  --login -c 'cd /home/$user/projects/sparky && export SPARKY_HTTP_ROOT=\"\" && export SPARKY_ROOT=/home/$user/.sparky/projects && raku bin/sparky-web.pl6 1>~/.sparky-web2.log 2>&1'"
);

# start service

service-restart "sparky-web";

#service-enable "sparky-web";

