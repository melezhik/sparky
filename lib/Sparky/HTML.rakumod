unit module Sparky::HTML;

use Sparky;
use Sparky::Security;

sub css () is export {

  my %conf = get-sparky-conf();

  qq:to /HERE/
  <meta charset="utf-8">
  <link
    rel="stylesheet"
    href="https://cdn.jsdelivr.net/npm/bulma@1.0.0/css/bulma.min.css"
  >
  <script defer src="https://use.fontawesome.com/releases/v5.14.0/js/all.js"></script>
  <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/10.4.1/styles/default.min.css">
  <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/10.4.1/highlight.min.js"></script>
  <script>hljs.initHighlightingOnLoad();</script>
  <!-- <link rel="stylesheet" href="{sparky-http-root()}/css/style.css"> -->
  HERE

}

sub navbar (Mu $user?, Mu $token?) is export {

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
          <a class="navbar-item" href="{sparky-http-root()}/{check-user($user,$token) ?? 'logout' !! 'login'}">
            {check-user($user,$token) ?? 'Logout' !! 'Login'}
          </a>
        </div>
      </div>
    </nav>
  HERE

}

