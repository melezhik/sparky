systemd-service "sparkyd-example", %(
  user => "root",
  workdir => "/root/projects/sparky",
  command => "/usr/bin/bash --login -c 'sparkyd --root=/root/projects/sparky/examples 2>/var/log/sparky-example.log'"
);

# start service

service-start "sparkyd-example";

