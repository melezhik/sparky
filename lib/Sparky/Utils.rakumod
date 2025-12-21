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

sub time-ago ($time) is export {

  my $past_time = DateTime.new($time.subst(" ","T"));
  my $now = DateTime.now;
  my $duration = $now.Instant - $past_time.Instant;

  my $seconds = $duration.round;
  my $minutes = floor($seconds / 60);
  my $hours = floor($minutes / 60);
  my $days = floor($hours / 24);

  # Calculate remaining units after extracting days, hours, etc.

  my $remaining_hours = $hours % 24;
  my $remaining_minutes = $minutes % 60;

  if ($days > 0) {
      return "$days day(s) and $remaining_hours hour(s) ago";
  } elsif ($hours > 0) {
      return "$hours hour(s) and $remaining_minutes minute(s) ago";
  } elsif ($minutes > 0) {
      return "$minutes minute(s) ago";
  } else {
      return "just now";
  }

}