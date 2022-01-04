package-install "libtemplate-perl carton";

my $user = "ubuntu";

systemd-service "sparky-web", %(
  user => $user,
  workdir => "/home/$user/projects/Sparky",
  command => "/usr/bin/bash  --login -c 'export PATH=~/.raku/bin/:$PATH &&  cd /home/$user/projects/Sparky && export SPARKY_HTTP_ROOT=\"\" && export SPARKY_ROOT=/home/$user/.sparky/projects && cro run 1>~/.sparky-web.log 2>&1'"
);

bash "systemctl daemon-reload";

# start service

service-restart "sparky-web";

#service-enable "sparky-web";

