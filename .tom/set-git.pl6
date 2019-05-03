#!perl6

task-run "set git", "git-base", %(
  email => 'melezhik@gmail.com',
  name  => 'Aleksei Melezhik',
  config_scope => 'local',
  set_credential_cache => 'on'
);
