# run `mi6 --keep release`
task-run "module release", "raku-utils-mi6", %(
  args => [
    ["yes"], 
    %( next-version => "=0.0.27" ),
    "release",
  ]
);