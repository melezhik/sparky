my $user = "melezhik";

systemd-service "sparkyd", %(
  user => $user,
  workdir => "/home/$user/projects/sparky",
  command => "/usr/bin/bash --login -c 'sparkyd --timeout=10'"
);

# start service

service-restart "sparkyd";
service-enable "sparkyd";

