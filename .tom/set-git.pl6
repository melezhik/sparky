#!perl6

task-run "set git", "git-base", %(
  email => 'user@email.com',
  name  => 'User Name',
  config_scope => 'local',
  set_credential_cache => 'on'
);
