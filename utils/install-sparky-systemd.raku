my $user = %*ENV<USER>;
my $workdir = "$*CWD";

my $s = systemd-service "sparkyd", %(
  :$user,
  :$workdir,
  command => "/usr/bin/bash --login -c 'sparkyd --timeout=20 2>&1 1>>~/.sparky/sparkyd.log'"
);

service-restart "sparkyd";
service-enable "sparkyd";

my $s = systemd-service "sparky", %(
  :$user,
  :$workdir,
  command => "/usr/bin/bash --login -c 'cro run 2>&1 1>>~/.sparky/sparky.log'"
);

service-restart "sparky";
service-enable "sparky";

