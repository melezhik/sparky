#!raku

my $home = %*ENV<HOME>;

directory "$home/projects/Sparky";

bash "sudo dnf install -y git make";

#bash "zef install https://github.com/melezhik/Sparrow6.git --/test";


git-scm "https://github.com/melezhik/sparky.git", %(
  to => "$home/projects/Sparky";
);

bash "zef install .", %(
  :description<install_sparky_deps>,
  :cwd("$home/projects/Sparky"),
);
