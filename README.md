# SYNOPSIS

Sparky is a flexible and minimalist continuous integration server written in Raku.

![Nice web UI](https://raw.githubusercontent.com/melezhik/sparky/master/images/sparky-web-ui4.png)

The essential features of Sparky:

* Defining builds times in crontab style
* Triggering builds using external APIs and custom logic
* Build scenarios defined as [Sparrow6](https://github.com/melezhik/Sparrow6) scripts
* [Nice set](https://github.com/melezhik/Sparrow6/blob/master/documentation/dsl.md) of predefined tasks is available
* Everything is kept in SCM repository - easy to port, maintain and track changes
* Builds gets run in one of 3 flavors - 1) on localhost 2) on remote machines via **ssh** 3) on **docker** instances
* Nice web UI to read build reports

Interested? Let's go ahead! (:

# Build status

[![Build Status](https://travis-ci.org/melezhik/sparky.svg?branch=master)](https://travis-ci.org/melezhik/sparky)

# Sparky workflow in 4 lines:

    $ sparkyd # run Sparky daemon to build your projects
    $ raku bin/sparky-web.raku # run Sparky web ui to see build statuses and reports
    $ nano ~/.sparky/projects/my-project/sparrowfile  # write a build scenario
    $ firefox 127.0.0.1:3000 # see what's happening

# Installation

    $ sudo apt-get install sqlite3
    $ git clone https://github.com/melezhik/sparky.git
    $ cd sparky && zef install .

# Setup

First you should run database initialization script to populate database schema:

    $ raku db-init.raku

# Running daemon

Then you need to run the sparky daemon

    $ sparkyd

* Sparky daemon traverses sub directories found at the project root directory.

* For every directory found initiate build process invoking sparky worker ( `sparky-runner.raku` ).

* Sparky root directory default location is `~/.sparky/projects`.

* Once all the sub directories gets passed, sparky daemon sleeps for $timeout seconds.

* A `timeout` option allows to balance a load on your system.

* You can change a timeout by applying `--timeout` parameter when running sparky daemon:

    $ sparkyd --timeout=600 # sleep 10 minutes

* You can also set a timeout by using `SPARKY_TIMEOUT` environment variable:

    $ SPARKY_TIMEOUT=30 sparkyd ...

Running sparky in demonized mode.

At the moment sparky can't demonize itself, as temporary workaround use linux `nohup` command:

    $ nohup sparkyd &

Or you can use Sparrowdo installer, which install service as systemd unit:

    $ nano utils/install-sparky-web-systemd.raku # change working directory and user
    $ sparrowdo --sparrowfile=utils/install-sparkyd-systemd.raku --no_sudo --localhost

# Running Web UI

And finally sparky has simple web ui to show builds statuses and reports.

To run Sparky web ui launch `sparky-web.raku` script from the `bin/` directory:

    $ raku bin/sparky-web.raku

This is [Bailador](https://github.com/Bailador/Bailador) application, so you can set any Bailador related options here.

For example:

    BAILADOR=host:0.0.0.0,port:5000 raku bin/sparky-web.raku

You can use Sparrowdo installer as well, which installs service as systemd unit:

    $ nano utils/install-sparky-web-.raku # change working directory, user and root directory
    $ sparrowdo --sparrowfile=utils/install-sparky-web-systemd.raku --no_sudo --localhost

# Creating first sparky project

Sparky project is just a directory located at the sparky root directory:

    $ mkdir ~/.sparky/projects/bailador-app

# Build scenario

Sparky is built on Sparrowdo, read [Sparrowdo](https://github.com/melezhik/sparrowdo)
_to know how to write Sparky scenarios_.

Here is a short example.

Say, we want to check out the Bailador source code from Git, install dependencies and then run unit tests:

    $ nano ~/.sparky/projects/bailador-app/sparrowfile

    package-install 'git';

    git-scm 'https://github.com/Bailador/Bailador.git';

    zef 'Path::Iterator';
    zef '.', %( depsonly => True );
    zef 'TAP::Harness';

    bash 'prove6 -l', %(
      debug => True,
      envvars => %(
        PATH => '/root/.rakudobrew/moar-master/install/share/perl6/site/bin:$PATH'
      )
    );

# Configure Sparky workers

By default the build scenario gets executed _on the same machine you run Sparky at_, but you can change this
to _any remote host_ setting Sparrowdo related parameters in the `sparky.yaml` file:

    $ nano ~/.sparky/projects/bailador-app/sparky.yaml

    sparrowdo:
      host: '192.168.0.1'
      ssh_private_key: /path/to/ssh_private/key.pem
      ssh_user: sparky
      no_index_update: true
      sync: /tmp/repo

You can read about the all [available parameters](https://github.com/melezhik/sparrowdo#sparrowdo-cli) in Sparrowdo documentation.

# Skip bootstrap

Sparrowdo bootstrap takes a while, if you don't need bootstrap ( sparrow client is already installed at a target host )
use `bootstrap: false` option:

    sparrowdo:
      bootstrap: false

# Purging old builds

To remove old build set `keep_builds` parameter in `sparky.yaml`:

    $ nano ~/.sparky/projects/bailador-app/sparky.yaml

    keep_builds: 10

That makes Sparky remove old build and only keep last `keep_builds` builds.

# Run by cron

It's possible to setup scheduler for Sparky builds, you should define `crontab` entry in sparky yaml file.
for example to run a build every hour at 30,50 or 55 minute say this:

    $ nano ~/.sparky/projects/bailador-app/sparky.yaml

    crontab: "30,50,55 * * * *"

Follow [Time::Crontab](https://github.com/ufobat/p6-time-crontab) documentation on crontab entries format.

# Manual run

If you want to build a project from web UI, use `allow_manual_run`:

    $ nano ~/.sparky/projects/bailador-app/sparky.yaml

    allow_manual_run: true

# Disable project

You can disable project builds by setting `disable` option to true:

    $ nano ~/.sparky/projects/bailador-app/sparky.yaml

    disabled: true

It's handy when you start a new project and don't want to add it into build pipeline.

# Downstream projects

You can run downstream projects by setting `downstream` field at the upstream project `sparky.yaml` file:

    $ nano ~/.sparky/projects/main/sparky.yaml

    downstream: downstream-project

# File triggering protocol (FTP)

Sparky FTP allows to _trigger_ builds automatically by just creating files with build _parameters_
in special format:

    nano $project/.triggers/foo-bar-baz.pl6

File should have a `*.pl6` extension and be located in project `.trigger` directory.

A content of the file should Raku code returning a Hash:

```raku
{
  description => "Build app",
  cwd => "/path/to/working/directory",
  sparrowdo => %(
    localhost => True,
    no_sudo   => True,
    conf      => "/path/to/file.conf"
  )
}
```

Sparky daemon parses files in `.triggers` and launch build per every file, removing file afterwards,
this process is called file triggering.

To separate different builds just create trigger files with unique names inside `$project/.trigger` directory.

FTP allows to create _supplemental_ APIs to implement more complex and custom build logic, while keeping Sparky itself simple.

## Trigger attributes

Those keys could be used in trigger Hash. All they are optional.

* `cwd`

Directory where sparrowfile is located, when a build gets run, the process will change to this directory.

* `description`

Arbitrary text description of build

* `sparrowdo`

Options for sparrowdo run, for example:

    %(

      host  => "foo.bar",
      ssh_user  => "admin",
      tags => "prod,backend"
    )

Should follow the format of sparky.yaml, `sparrowdo` section

* `key`

A unique key

# Sparky plugins

Sparky plugins are extensions points to add extra functionality to Sparky builds.

These are Raku modules get run _after_ a Sparky project finishes or in other words when a build is completed.

To use Sparky plugins you should:

* Install plugins as Raku modules

* Configure plugins in project's `sparky.yaml` file

## Install Sparky plugins

You should install a module on the same server where you run Sparky at. For instance:

    $ zef install Sparky::Plugin::Email # Sparky plugin to send email notifications

## Configure Sparky

In project's `sparky.yaml` file define plugins section, it should be list of Plugins and its configurations.

For instance:

    $ cat sparky.yaml

    plugins:
      - Sparky::Plugin::Email:
        parameters:
          subject: "I finished"
          to: "happy@user.email"
          text: "here will be log"
      - Sparky::Plugin::Hello:
        parameters:
          name: Sparrow

## Creating Sparky plugins

Technically speaking  Sparky plugins should be just Raku modules.

For instance, for mentioned module Sparky::Plugin::Email we might have this header lines:

    use v6;

    unit module Sparky::Plugin::Hello;


That is it.

The module should have `run` routine which is invoked when Sparky processes a plugin:

    our sub run ( %config, %parameters ) {

    }

As we can see the `run` routine consumes its parameters as Raku Hash, these parameters are defined at mentioned `sparky.yaml` file,
at plugin `parameters:` section, so this is how you might handle them:

    sub run ( %config, %parameters ) {

      say "Hello " ~ %parameters<name>;

    }

You can use `%config` Hash to access Sparky guts:

* `%config<project>`      - the project name
* `%config<build-id>`     - the build number of current project build
* `%cofig<build-state>`   - the state of the current build

For example:

```
    sub run ( %config, %parameters ) {

      say "build id is: " ~ %parameters<build-id>;

    }
```

Alternatively you may pass _some_ predefined parameters plugins:

* %PROJECT% - equivalent of `%config<project>`
* %BUILD-STATE% - equivalent of `%config<build-state>`
* %BUILD-ID% - equivalent of `%config<build-id>`

For example:

```
    $ cat sparky.yaml

    plugins:
      - Sparky::Plugin::Hello:
        parameters:
          name: Sparrow from project %PROJECT%
```

## Limit plugin run scope

You can defined _when_ to run plugin, here are 3 run scopes:

* `anytime` - run plugin irrespective of a build state. This is default value
* `success` - run plugin only if build has succeeded
* `fail`    - run plugin only if build has  failed

Scopes are defined at `run_scope:` parameter:


      - Sparky::Plugin::Hello:
        run_scope: fail
        parameters:
          name: Sparrow


## An example of Sparky plugins

An example Sparky plugins are:

* [Sparky::Plugin::Hello](https://github.com/melezhik/sparky-plugin-hello)
* [Sparky::Plugin::Notify::Email](https://github.com/melezhik/sparky-plugin-notify-email)

# Command line client

You can build the certain project using sparky command client called `sparky-runner.raku`:

    $ sparky-runner.raku --dir=~/.sparky/projects/bailador-app

Or just:

    $ cd ~/.sparky/projects/bailador-app && sparky-runner.raku

# Sparky runtime parameters

All this parameters could be overridden by command line ( `--root`, `--work-root` )

##  Rood directory

This is sparky root directory, or directory where Sparky looks for the projects to get built:

    ~/.sparky/projects/

##  Work directory

This is working directory where sparky might place some stuff, useless at the moment:

    ~/.sparky/work

# Environment variables

## SPARKY_SKIP_CRON

You can disable cron check to run project forcefully, by setting `SPARKY_SKIP_CRON` environment variable:

    $ export SPARKY_SKIP_CRON=1 && sparkyd

## SPARKY_ROOT

Sets the sparky root directory

## SPARKY_HTTP_ROOT

Set Sparky web application http root. Useful when proxy application through Nginx.

## SPARKY_TIMEOUT

Sets timeout for sparky workers, see [Running daemon](#running-daemon) section.

# Running under other databases engines (MySQL, PostgreSQL)

By default Sparky uses sqlite as database engine, which makes it easy to use when developing.
However sqlite has limitation on transactions locking whole database when doing inserts/updates (Database Is Locked errors).

if you prefer other databases here is guideline.

## Create sparky configuration file

You should defined database engine and connection parameters, say we want to use MySQL:

    $ nano ~/sparky.yaml

    database:
      engine: mysql
      host: $dbhost
      port: $dbport
      name: $dbname
      user: $dbuser
      pass: $dbpassword

For example:

    database:
      engine: mysql
      host: "127.0.0.1"
      port: 3306
      name: sparky
      user: sparky
      pass: "123"

## Installs dependencies

Depending on platform it should be client needed for your database API, for example for Debian we have to:

    $ sudo yum install mysql-client

## Creating database user, password and schema

DB init script will generate database schema, provided that user defined and sparky configuration file has access to
the database:

    $ raku db-init.raku

That is it, now sparky runs under MySQL!

# Change UI theme

Sparky uses [Bulma](https://bulma.io/) as a CSS framework, you can easily change the theme
through sparky configuration file:


    $ nano ~/sparky.yaml

    ui:
      theme: cosmo

The list of available themes is on [https://jenil.github.io/bulmaswatch/](https://jenil.github.io/bulmaswatch/)

# Trigger jobs from HTTP API

    POST /build/project/$project

# Examples

You can see examples of sparky scenarios in `examples/` folder.

# See also

[Bailador](https://github.com/Bailador/Bailador) - A light-weight route-based web application framework for Perl 6.
[Sparky-docker](https://github.com/melezhik/sparky-docker) - Run Sparky as Docker container.

# Author

Alexey Melezhik
