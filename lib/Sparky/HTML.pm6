unit module Sparky::HTML;

use Sparky;

sub css is export {

  my %conf = get-sparky-conf();

  my $theme ;

  if %conf<ui> && %conf<ui><theme> {
    $theme = %conf<ui><theme>
  } else {
    $theme = "solar";
  }

  qq:to /HERE/
  <meta charset="utf-8">
  <link rel="stylesheet" href="https://unpkg.com/bulmaswatch/$theme/bulmaswatch.min.css">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/markdown-it/12.0.4/markdown-it.min.js" integrity="sha512-0DkA2RqFvfXBVeti0R1l0E8oMkmY0X+bAA2i02Ld8xhpjpvqORUcE/UBe+0KOPzi5iNah0aBpW6uaNNrqCk73Q==" crossorigin="anonymous"></script>
  <script defer src="https://use.fontawesome.com/releases/v5.14.0/js/all.js"></script>
  <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/10.4.1/styles/default.min.css">
  <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/10.4.1/highlight.min.js"></script>
  <script>hljs.initHighlightingOnLoad();</script>
  HERE

}

sub navbar is export {

  qq:to /HERE/
    <nav class="navbar" role="navigation" aria-label="main navigation">
      <div class="navbar-brand">
        <a role="button" class="navbar-burger burger" aria-label="menu" aria-expanded="false" data-target="navbarBasicExample">
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
        </a>
      </div>
      <div id="navbarBasicExample" class="navbar-menu">
        <div class="navbar-start">
          <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/">
            Projects
          </a>
          <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/builds">
            Recent Builds
          </a>
          <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/queue">
            Queue
          </a>
          <div class="navbar-item has-dropdown is-hoverable">
            <a class="navbar-link">
              More
            </a>
            <div class="navbar-dropdown">
              <a class="navbar-item" href="{%*ENV<SPARKY_HTTP_ROOT>}/about">
                About
              </a>
              <a class="navbar-item" href="https://github.com/melezhik/sparky">
                Docs
              </a>
              <a class="navbar-item" href="https://github.com/melezhik/sparky/issues">
                Report an issue
              </a>
            </div>
          </div>
        </div>
      </div>
    </nav>
  HERE

}