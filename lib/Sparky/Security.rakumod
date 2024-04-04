unit module Sparky::Security;
use Sparky;
use Sparky::Utils;
use JSON::Fast;
use YAMLish;

sub gen-token is export {

  ("a".."z","A".."Z",0..9).flat.roll(8).join

}

sub check-user (Mu $user, Mu $token, $project?) is export {

  return False unless $user;

  return False unless $token;

  my $any-user = "*";

  if "{cache-root()}/users/{$user}/tokens/{$token}".IO ~ :f {
    #say "user $user, token - $token - validation passed";
    return True unless $project;
    my $list =  load-acl-list();
    # in case no ACL, allow all authenticated users to do all
    unless $list {
      say "check-user: no ACL found, allow user [$user] on default basis";
      return True 
    }

    say "check-user: ACL loaded: {$list.perl}";
    
    if $list<projects>{$project}<deny><users> && 
       $list<projects>{$project}<deny><users>.isa(List) &&
       $list<projects>{$project}<deny><users>.Set{$user} {
          say "check-user: deny user [$user] build project [$project] on project deny basis";
          return False;
    } elsif $list<global><deny><users> && 
      $list<global><deny><users>.isa(List) &&
      $list<global><deny><users>.Set{$user} {
          say "check-user: deny user [$user] build project [$project] on global deny basis";
          return False;
    } elsif $list<projects>{$project}<allow><users> &&
      $list<projects>{$project}<allow><users>.isa(List) &&
      $list<projects>{$project}<allow><users>.Set{$user} {
          say "check-user: allow user [$user] to build project [$project] on project allow basis";
          return True;
    } elsif $list<global><allow><users> && 
      $list<global><allow><users>.isa(List) &&
      (
        $list<global><allow><users>.Set{$user} or
        $list<global><allow><users>.Set{$any-user}
      ) {
          say "check-user: allow user [$user] build project [$project] on global allow basis";
          return True;
    } else {
      say "check-user: deny user [$user] build project [$project] on default basis";
      return False
    }
  } else {
      say "check-user: user $user, token - $token - validation failed";
      return False
  }
}

sub user-create-account (Mu $user, $data = {}) is export {

    mkdir "{cache-root()}/users";

    mkdir "{cache-root()}/users/{$user}";

    mkdir "{cache-root()}/users/{$user}/tokens";

    "{cache-root()}/users/{$user}/meta.json".IO.spurt(
        to-json($data)
    );

    say "auth: save user data to {cache-root()}/users/{$user}/meta.json";

    my $tk = gen-token();

    "{cache-root()}/users/$user/tokens/{$tk}".IO.spurt("");

    say "auth: set user token to {$tk}";

    return $tk;

}


sub load-acl-list {

  if "{%*ENV<HOME>}/.sparky/acl/hosts/{hostname()}/list.yaml".IO ~~ :e {
    say "acl: load acl from {%*ENV<HOME>}/.sparky/acl/hosts/{hostname()}/list.yaml";
    return load-yaml("{%*ENV<HOME>}/.sparky/acl/hosts/{hostname()}/list.yaml".IO.slurp);
  } elsif "{%*ENV<HOME>}/.sparky/acl/list.yaml".IO ~~ :e {
    say "acl: load acl from {%*ENV<HOME>}/.sparky/acl/list.yaml";
    return load-yaml("{%*ENV<HOME>}/.sparky/acl/list.yaml".IO.slurp);
  } else {
    return
  }

}
