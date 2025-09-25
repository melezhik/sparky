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

sub terminate-job ( $pid-file ) is export {

  if $pid-file.IO ~~ :f {
    my $pid = $pid-file.IO.slurp.chomp;
    say "utils: terminate sparky job with all sub processes: pid file={$pid-file} PID=$pid";
    shell('list_descendants () { local children=$(pgrep -P "$1"); for pid in $children; do list_descendants "$pid"; done; echo "$children"; }; echo "kill " $(list_descendants %PID%); kill $(list_descendants %PID%); echo'.subst("%PID%",$pid,:g));
  } 

}

sub update-sys-report( $file, $line ) is export {

  say "utils: update sys report: file=$file line=$line";
  my $fh = open :a, $file;
  $fh.say: DateTime.now ~ " >> " ~ $line;
  $fh.close;

}