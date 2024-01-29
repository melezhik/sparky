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
      $search = $search{$i}
    } elsif $search{$i}:exists {
      return $search{$i};
    } else {
      return
    }
  }
}
