unit module Sparky::Utils;

sub hostname () is export {

  return %*ENV<HOSTNAME> ??
  %*ENV<HOSTNAME> !!
  qx[hostname].chomp;

}


sub get-template-var ($data,$path) is export {

  return unless $data;
  return unless $path;

  my $search = $data;

  for $path.split('.') -> $i {
    if $search{$i}:exists && $search{$i}.isa(Hash) {
      say "get-template-var: $i - enter new path";
      $search = $search{$i}
    } elsif $search{$i}:exists {
      say "get-template-var: $i - found OK";
      return $search{$i};
    } else {
      say "get-template-var: $i - found FAIL";
      return
    }
  }
}
