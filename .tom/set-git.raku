#!perl6

task-run "set git", "git-base", %(
  email => 'kibijel@gmail.com',
  name  => 'SP1983',
  config_scope => 'local',
  set_credential_cache => 'on'
);
