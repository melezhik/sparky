package-install "libtemplate-perl carton";

my $user = "sph";

systemd-service "sparky-web", %(
  user => $user,
  workdir => "/home/$user/projects/sparky",
  command => "/usr/bin/bash  --login -c 'cro run 1>>~/.sparky/sparky.log 2>&1'"
);

bash "systemctl daemon-reload";

# start service

service-restart "sparky-web";

service-enable "sparky-web";

