my $user = "sph";

systemd-service "sparkyd", %(
  user => $user,
  workdir => "/home/$user/projects/sparky",
  command => "/usr/bin/bash --login -c 'sparkyd --timeout=20 2>&1 1>>~/.sparky/sparkyd.log'"
);

# start service

service-restart "sparkyd";
service-enable "sparkyd";

