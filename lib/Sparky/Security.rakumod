unit module Sparky::Security;
use Sparky;
use JSON::Fast;

sub gen-token is export {

  ("a".."z","A".."Z",0..9).flat.roll(8).join

}

sub check-user (Mu $user, Mu $token) is export {

  return False unless $user;

  return False unless $token;

  if "{cache-root()}/users/{$user}/tokens/{$token}".IO ~ :f {
    #say "user $user, token - $token - validation passed";
    return True
  } else {
    say "user $user, token - $token - validation failed";
    return False
  }

}

sub access-token (Mu $user) is export {
  from-json("{cache-root()}/users/{$user}/meta.json".IO.slurp)<access_token>;
}

sub user-create-account (Mu $user, $data = {}) is export {

    mkdir "{cache-root()}/users";

    mkdir "{cache-root()}/users/{$user}";

    mkdir "{cache-root()}/users/{$user}/tokens";

    "{cache-root()}/users/{$user}/meta.json".IO.spurt(
        to-json($data)
    );

    my $tk = gen-token();

    "{cache-root()}/users/$user/tokens/{$tk}".IO.spurt("");

    say "set user token to {$tk}";

    return $tk;

}