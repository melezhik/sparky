unit module Sparky::HTML;

use Sparky;

sub css (Mu $theme) is export {

  my %conf = get-sparky-conf();

  qq:to /HERE/
  <meta charset="utf-8">
  <link rel="stylesheet" href="https://unpkg.com/bulmaswatch/$theme/bulmaswatch.min.css">
  <script defer src="https://use.fontawesome.com/releases/v5.14.0/js/all.js"></script>
  <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/10.4.1/styles/default.min.css">
  <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/10.4.1/highlight.min.js"></script>
  <script>hljs.initHighlightingOnLoad();</script>
  <!-- <link rel="stylesheet" href="{sparky-http-root()}/css/style.css"> -->
  HERE

}

sub navbar is export {

  qq:to /HERE/
    <nav class="navbar is-transparent" role="navigation" aria-label="main navigation">
      <div class="navbar-brand">
       <a role="button" class="navbar-burger burger" aria-label="menu" aria-expanded="false" data-target="navbarBasicExample">
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
        </a>
      </div>
      <div id="navbarBasicExample" class="navbar-menu">
        <div class="navbar-start">
          <a class="navbar-item" href="{sparky-http-root()}/">
            Projects
          </a>
          <a class="navbar-item" href="{sparky-http-root()}/builds">
            Recent Builds
          </a>
          <a class="navbar-item" href="{sparky-http-root()}/queue">
            Queue
          </a>
          <div class="navbar-item has-dropdown is-hoverable">
            <a class="navbar-link">
              More
            </a>
            <div class="navbar-dropdown">
              <a class="navbar-item" href="{sparky-http-root()}/about">
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
          <div class="navbar-item has-dropdown is-hoverable">
            <a class="navbar-link">
              Theme
            </a>
            <div class="navbar-dropdown">
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=cerulean">cerulean</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=cosmo">cosmo</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=cyborg">cyborg</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=darkly">darkly</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=flatly">flatly</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=journal">journal</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=litera">litera</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=lumen">lumen</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=lux">lux</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=materia">materia</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=minty">minty</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=nuclear">nuclear</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=pulse">pulse</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=sandstone">sandstone</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=simplex">simplex</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=slate">slate</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=solar">solar</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=spacelab">spacelab</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=superhero">superhero</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=united">united</a>
              <a class="navbar-item" href="{sparky-http-root()}/set-theme?theme=yeti">yeti</a>
            </div>
          </div>
        </div>
      </div>
    </nav>
  HERE

}

sub default-theme is export {
  my $t;
  my %conf = get-sparky-conf();
  if %conf<ui> && %conf<ui><theme> {
    $t = %conf<ui><theme>
  } else {
    $t = "cosmo";
  }
  return $t;
}
