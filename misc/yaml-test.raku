use YAMLish;

my $data = load-yaml('plugins:
  Sparky::Plugin::Email:
    parameters:
      subject: "I finished"
      to: "happy@user.email"
      text: "here will be log"
  Sparky::Plugin::Hello:
    parameters:
      name: Sparrow
');

say $data.perl;

for $data<plugins><>.kv -> $k, $v {
  say $k;
}
