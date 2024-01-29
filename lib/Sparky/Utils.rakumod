unit module Sparky::Utils;

sub hostname () is export {

  return %*ENV<HOSTNAME> ??
  %*ENV<HOSTNAME> !!
  qx[hostname].chomp;

}

