package-install "libtemplate-perl carton";

my $user = "ubuntu";

systemd-service "sparky-web", %(
  user => $user,
  workdir => "/home/$user/projects/Sparky",
  command => "/usr/bin/bash  --login -c 'cd /home/$user/projects/Sparky && export SPARKY_HTTP_ROOT=\"\" && export SPARKY_ROOT=/home/$user/.sparky/projects && raku bin/sparky-web.raku 1>~/.sparky-web.log 2>&1'"
);

# start service

service-restart "sparky-web";

#service-enable "sparky-web";

