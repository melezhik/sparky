systemd-service "sparkyd", %(
  user => "scheck",
  workdir => "/home/scheck/projects/sparky",
  command => "/usr/bin/bash --login -c 'sparkyd --root=/home/scheck/projects/RakuDist/sparky/'"
);

# start service

service-start "sparkyd";
service-enable "sparkyd";

