# SYNOPSIS

Sparky is a flexible and minimalist continuous integration server and distribute tasks runner written in Raku.

![Sparky Logo](https://raw.githubusercontent.com/melezhik/sparky/master/logos/sparky.small.png)

Sparky features:

* Defining builds scheduling times in crontab style
* Triggering builds using external APIs and custom logic
* Build scenarios are defined as Raku scripts with support of [Sparrow6](https://github.com/melezhik/Sparrow6/blob/master/documentation/dsl.md) DSL 
* CICD code could be extended using various scripting languages
* Everything is kept in SCM repository - easy to port, maintain and track changes
* Builds gets run in one of 3 flavors - 1) on localhost 2) on remote machines via ssh 3) on docker instances
* Nice web UI to run build and read reports
* Runs in a peer-to-peer network fashion with distributed tasks support

# Build status

![github actions](https://github.com/melezhik/sparky/actions/workflows/main.yml/badge.svg)
![SparkyCI](https://ci.sparrowhub.io/project/gh-melezhik-sparky/badge)

# Sparky workflow in 4 lines:

```bash
$ nohup sparkyd & # run Sparky daemon to trigger build jobs
$ nohup cro run & # run Sparky CI UI to see build statuses and reports
$ nano ~/.sparky/projects/my-project/sparrowfile  # write a build scenario
$ firefox 127.0.0.1:4000 # run builds and get reports
```

# Installation

```bash
$ sudo apt-get install sqlite3
$ git clone https://github.com/melezhik/sparky.git
$ cd sparky && zef install .
```

# Setup

Run database initialization script to populate database schema:

```bash
$ raku db-init.raku
```

# Running daemon

```bash
$ sparkyd
```

`sparkyd` should be in your PATH, usually you need to `export PATH=~/.raku/bin:$PATH` after 

`zef install .` 

* Sparky daemon traverses sub directories found at the project root directory.

* For every directory found initiate build process invoking sparky worker ( `sparky-runner.raku` ).

* Sparky root directory default location is `~/.sparky/projects`.

* Once all the sub directories are passed, sparky daemon sleeps for $timeout seconds.

* A `timeout` option allows to balance a load on your system.

* You can change a timeout by applying `--timeout` parameter when running sparky daemon:

```bash
$ sparkyd --timeout=600 # sleep 10 minutes
```

* You can also set a timeout by using `SPARKY_TIMEOUT` environment variable:

```bash
$ SPARKY_TIMEOUT=30 sparkyd ...
```

Running sparky in demonized mode.

At the moment sparky can't demonize itself, as temporary workaround use linux `nohup` command:

```bash 
$ nohup sparkyd &
```

To install sparkyd as a systemd unit:

```bash
$ nano utils/install-sparky-web-systemd.raku # change working directory and user
$ sparrowdo --sparrowfile=utils/install-sparkyd-systemd.raku --no_sudo --localhost
```

# Sparky Web UI

And finally Sparky has a simple web UI to show builds statuses and reports.

To run Sparky CI web app:

```bash
$ nohup cro run &
```

To install Sparky CI web app as a systemd unit:

```bash
$ nano utils/install-sparky-web-systemd.raku # change working directory, user and root directory
$ sparrowdo --sparrowfile=utils/install-sparky-web-systemd.raku --no_sudo --localhost
```

## Setting web app tcp parameters

By default web app listens on host `0.0.0.0`, port `4000`, to configure web app tcp host and port set `SPARKY_HOST` and  `SPARKY_TCP_PORT` variables in `~/sparky.yaml`

```yaml
SPARKY_HOST: 127.0.0.1
SPARKY_TCP_PORT: 5000 
```

# Security

## Authentication

Sparky web server _comes with_ two authentication protocols,
choose proper one depending on your requirements, see details
at [docs/auth.md](https://github.com/melezhik/sparky/blob/master/docs/auth.md)

## ACL

Sparky ACL allows to create access control lists to manage role based access to Sparky resources, see [docs/acl.md](https://github.com/melezhik/sparky/blob/master/docs/acl.md)

# Creating first sparky project

Sparky project is just a directory located at the sparky root directory:

```bash
$ mkdir ~/.sparky/projects/teddy-bear-app
```

# Build scenario

Sparky is built on top of Sparrow/Sparrowdo, read [Sparrowdo](https://github.com/melezhik/sparrowdo)
_to know how to write Sparky scenarios_. 

Here is a short example.

Git check out a Raku project, install dependencies and run unit tests:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparrowfile
```

And add content like this:

```raku

directory "project";

git-scm 'https://github.com/melezhik/rakudist-teddy-bear.git', %(
  to => "project",
);

zef "{%*ENV<PWD>}/project", %( 
  depsonly => True 
);

zef 'TAP::Harness App::Prove6';

bash 'prove6 -l', %(
  debug => True,
  cwd => "{%*ENV<PWD>}/project/"
);
```

# Configure Sparky workers

By default the build scenario gets executed _on the same machine you run Sparky at_, but you can change this
to _any remote host_ setting Sparrowdo related parameters in the `sparky.yaml` file:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

And define worker configuration:

```yaml
sparrowdo:
  host: '192.168.0.1'
  ssh_private_key: /path/to/ssh_private/key.pem
  ssh_user: sparky
  no_index_update: true
  sync: /tmp/repo
```

Follow [sparrowdo cli](https://github.com/melezhik/sparrowdo#sparrowdo-cli) documentation for `sparrowdo` parameters explanation.

# Skip bootstrap

Sparrowdo bootstrap takes a while, if you don't need bootstrap ( sparrow client is already installed at a target host )
use `bootstrap: false` option:

```yaml
sparrowdo:
  bootstrap: false
```

# Purging old builds

To remove old build set `keep_builds` parameter in `sparky.yaml`:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

Put number of past builds to keep:

```yaml
keep_builds: 10
```

That makes Sparky remove old build and only keep last `keep_builds` builds.

# Run by cron

It's possible to setup scheduler for Sparky builds, you should define `crontab` entry in sparky yaml file.
for example to run a build every hour at 30,50 or 55 minute say this:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

With this schedule:

```cron
crontab: "30,50,55 * * * *"
```

Follow [Time::Crontab](https://github.com/ufobat/p6-time-crontab) documentation on crontab entries format.

# Manual run

If you want to build a project from web UI, use `allow_manual_run`:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

And activate manual run:
```yaml
allow_manual_run: true
```

# Trigger build by SCM changes

** warning ** - the feature is not properly tested, feel free to post issues or suggestions

To trigger Sparky builds on SCM changes, define `scm` section in `sparky.yaml` file:

```yaml
scm:
  url: $SCM_URL
  branch: $SCM_BRANCH
```

Where:

* `url` - git URL
* `branch` - git branch, optional, default value is `master`

For example:

```yaml
scm:
  url: https://github.com/melezhik/rakudist-teddy-bear.git
  branch: master
```

Once a build is triggered respected SCM attributes available via `tags()<SCM_*>` elements:

```raku
directory "scm";

say "current commit is: {tags()<SCM_SHA>}";

git-scm tags()<SCM_URL>, %(
  to => "scm",
  branch => tags<SCM_BRANCH>
);

bash "ls -l {%*ENV<PWD>}/scm";
```

To set default values for SCM_URL and SCM_BRANCH, use sparrowdo `tags`:


`sparky.yaml`:

```yaml
  sparrowdo:
    tags: SCM_URL=https://github.com/melezhik/rakudist-teddy-bear.git,SCM_BRANCH=master
```

These is useful when trigger build manually.

# Flappers protection mechanism 

Flapper protection mechanism kicks out SCM urls that are timeouted (certain amount of time) during git connection, from scheduling, this mechanism protects sparkyd worker from stalling.

To disable flappers protection mechanism, set `SPARKY_FLAPPERS_OFF` environment variable
or adjust `~/sparky.yaml` configuration file:

```yaml
worker:
  flappers_off: true
```

# Disable project

You can disable project builds by setting `disable` option to true:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml

disabled: true
```
It's handy when you start a new project and don't want to add it into build pipeline.

# Advanced topics

# UI DSL

Sparky  UI DSL allows to grammatically describe UI for Sparky jobs
and pass user input into scenario as variables.

Read more at [docs/ui.md](https://github.com/melezhik/sparky/blob/master/docs/ui.md)

## Downstream jobs

Downstream jobs get run after some _main_ job has finished.

Read more at [docs/downstream.md](https://github.com/melezhik/sparky/blob/master/docs/downstream.md)

## Sparky triggering protocol (STP)

Sparky Triggering Protocol allows to trigger jobs automatically by creating files in special format

Read more at [docs/stp.md](https://github.com/melezhik/sparky/blob/master/docs/stp.md)

## Job API

Job API allows to trigger new builds from a main scenario. 

Read more at [docs/job_api.md](https://github.com/melezhik/sparky/blob/master/docs/job_api.md)

## Sparky plugins

Sparky plugins are extensions points to add extra functionality to Sparky builds.

Read more at [docs/plugins.md](https://github.com/melezhik/sparky/blob/master/docs/plugins.md)

# HTTP API

Sparky HTTP API allows execute Sparky jobs remotely over HTTP

Read more at [docs/api.md](https://github.com/melezhik/sparky/blob/master/docs/api.md)

# Databases support

Sparky keeps it's data in database, by default it uses sqlite,
following databases are supported:

* SQLite
* MySQL/MariaDB
* PostgreSQL

Read more at [docs/database.md](https://github.com/melezhik/sparky/blob/master/docs/database.md)

# SSL Support

Sparky web server may run on SSL. To enable this add a couple of parameters to `~/sparky.yaml`

configuration file:

```
SPARKY_USE_TLS: true
tls:
 private-key-file: '/home/user/.sparky/certs/www.example.com.key'
 certificate-file: '/home/user/.sparky/certs/www.example.com.cert'
```

`SPARKY_USE_TLS` enables SSL mode and `tls` section has paths to ssl certificate ( key and certificate parts ).

# Command line client

You can build the certain project using sparky command client called `sparky-runner.raku`:

```bash
$ sparky-runner.raku --dir=/home/user/.sparky/projects/teddy-bear-app
```

Or just:

```bash
$ cd ~/.sparky/projects/teddy-bear-app && sparky-runner.raku
```

# Sparky runtime parameters

All this parameters could be overridden by command line ( `--root`, `--work-root` )

##  Root directory

This is Sparky root directory, or directory where Sparky looks for jobs descriptions:

```bash
~/.sparky/projects/
```

##  Work directory

This is working directory where sparky might place some stuff, useless at the moment:

```bash
~/.sparky/work
```

# Environment variables

## SPARKY_SKIP_CRON

You can disable cron check to run project forcefully, by setting `SPARKY_SKIP_CRON` environment variable:

```bash
$ export SPARKY_SKIP_CRON=1 && sparkyd
```

## SPARKY_MAX_JOBS

Threshold of concurrent jobs maximum number. Use it to protect Sparky server from overload.

(WARNING! This variable is not currently supported)

## SPARKY_FLAPPERS_OFF

Disable flappers mechanism, see "Flappers mechanism" section.

## SPARKY_ROOT

Sets the sparky root directory

## SPARKY_HTTP_ROOT

Set sparky web application http root. Useful when proxy application through Nginx:

    SPARKY_HTTP_ROOT='/sparky' cro run

## SPARKY_TIMEOUT

Sets timeout for sparky workers, see [Running daemon](#running-daemon) section.

## SPARKY_JOB_TIMEOUT

How many seconds wait till a job is considered as timeouted (used in Sparky Job API calls).


# CSS

Sparky uses [Bulma](https://bulma.io/) as CSS framework

# Sparky job examples

Examples of various Sparky jobs could be found at `examples/` folder.

# See also

* [Cro](https://cro.services) - Raku Web Framework

* [Sparky-docker](https://github.com/melezhik/sparky-docker) - Run Sparky as Docker container

# Author

Alexey Melezhik
