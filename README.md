# SYNOPSIS

Sparky is a flexible and minimalist continuous integration server and distribute tasks runner written in Raku.

![Sparky Logo](https://raw.githubusercontent.com/melezhik/sparky/master/logos/sparky.small.png)

Sparky features:

* Defining jobs scheduling times in crontab style
* Triggering jobs using external APIs and custom logic
* Jobs scenarios are pure Raku code with additional support of [Sparrow6](https://github.com/melezhik/Sparrow6/blob/master/documentation/dsl.md) automation framework
* Use of plugins on different programming languages
* Everything is kept in SCM repository - easy to port, maintain and track changes
* Jobs get run in one of 3 flavors - 1) on localhost 2) on remote machines via ssh 3) on docker instances
* Nice web UI to run jobs and read reports
* Could be runs in a peer-to-peer network fashion with distributed tasks support

# Build status

![Github actions](https://github.com/melezhik/sparky/actions/workflows/main.yml/badge.svg)
![SparrowCI](https://ci.sparrowhub.io/project/gh-melezhik-sparky/badge)

# Sparky workflow in 4 lines:

```bash
$ nohup sparkyd & # run Sparky daemon to trigger jobs
$ nohup cro run & # run Sparky CI UI to see job statuses and reports
$ nano ~/.sparky/projects/my-project/sparrowfile  # write a job scenario
$ firefox 127.0.0.1:4000 # run jobs and get reports
```

# Installation

```bash
$ sudo apt-get install sqlite3
$ git clone https://github.com/melezhik/sparky.git
$ cd sparky && zef install .
```

# Database initialization

Run database initialization script to populate database schema:

```bash
$ raku db-init.raku
```

# Job scheduler

To run Sparky jobs scheduler runs in console:

```bash
$ sparkyd
```

`sparkyd` should be in your PATH, usually you need to `export PATH=~/.raku/bin:$PATH` after 

`zef install .` 

* Sparky daemon traverses sub directories found at the project root directory.

* For every directory found initiate job run process invoking sparky worker ( `sparky-runner.raku` ).

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

Running job scheduler in demonized mode:

```bash 
$ nohup sparkyd &
```

To install sparkyd as a systemd unit:

```bash
$ nano utils/install-sparky-web-systemd.raku # change working directory and user
$ sparrowdo --sparrowfile=utils/install-sparkyd-systemd.raku --no_sudo --localhost
```

# Sparky Web UI

Sparky has a simple web UI to allow trigger jobs and get reports.

To run Sparky UI web application:

```bash
$ cro run
```

To install Sparky CI web app as a systemd unit:

```bash
$ nano utils/install-sparky-web-systemd.raku # change working directory, user and root directory
$ sparrowdo --sparrowfile=utils/install-sparky-web-systemd.raku --no_sudo --localhost
```

---

By default Sparky UI application listens on host `0.0.0.0`, port `4000`, 
to override these settings set  `SPARKY_HOST`, `SPARKY_TCP_PORT` 
in `~/sparky.yaml` configuration file:

```yaml
SPARKY_HOST: 127.0.0.1
SPARKY_TCP_PORT: 5000 
```

# Sparky jobs

Sparky job is just a directory located at the sparky root directory:

```bash
$ mkdir ~/.sparky/projects/teddy-bear-app
```

Sparky uses pure [Raku](https://raku.org) as a job language, for example:

```bash
$ nano ~/.sparky/projects/hello-world/sparrowfile
```

```raku
#!raku
say "hello Sparky!";
```

To leverage useful tasks and plugins, Sparky is fully integrated with [Sparrow](https://github.com/melezhik/Sparrow6) automation framework.

Here in example of job that checks out a Raku project, install dependencies and run unit tests:

```bash
$ nano ~/.sparky/projects/raku-build/sparrowfile
```

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

Repository of available Sparky plugins - [https://sparrowhub.io](https://sparrowhub.io)

# Sparky workers

By default the job scenario get executed _on the same machine you run Sparky at_, but you can change this to _any remote host_ setting Sparrowdo section in `sparky.yaml` file:

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

## Skip bootstrap

Sparrowdo bootstrap takes a while, if you don't need bootstrap ( sparrow client is already installed at a target host )
use `bootstrap: false` option:

```yaml
sparrowdo:
  bootstrap: false
```

## Purging old builds

To remove old job builds set `keep_builds` parameter in `sparky.yaml`:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

Put number of builds to keep:

```yaml
keep_builds: 10
```

That makes Sparky remove old builds and only keep last `keep_builds` builds.

## Run jobs by cron

It's possible to setup scheduler for Sparky builds, you should define `crontab` entry in sparky yaml file.

For example, to run a job every hour at 30,50 or 55 minutes:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

```cron
crontab: "30,50,55 * * * *"
```

Follow [Time::Crontab](https://github.com/ufobat/p6-time-crontab) documentation on crontab entries format.

## Manual run

To trigger job manually from web UI, use `allow_manual_run`:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

```yaml
allow_manual_run: true
```

## Trigger job by SCM changes

To trigger Sparky jobs on SCM changes, define `scm` section in `sparky.yaml` file:

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

Once a job is triggered respected SCM data is available via `tags()<SCM_*>` function:

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

These is useful when trigger job manually.

## Flappers protection mechanism 

Flapper protection mechanism kicks out SCM urls that are timeouted (certain amount of time) during git connection, from scheduling, this mechanism protects sparkyd worker from stalling.

To disable flappers protection mechanism, set `SPARKY_FLAPPERS_OFF` environment variable
or adjust `~/sparky.yaml` configuration file:

```yaml
worker:
  flappers_off: true
```

## Disable jobs

To prevent Sparky job from execution use `disable` option:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml

disabled: true
```

# Advanced topics

Following are some advanced topics, that might be of interest once you
are familiar with a basis.

# Job UIs

Sparky UI DSL allows to grammatically describe UI for Sparky jobs
and pass user input into scenario as variables.

Read more at [docs/ui.md](https://github.com/melezhik/sparky/blob/master/docs/ui.md)

## Downstream jobs

Downstream jobs get run after some _main_ job has finished.

Read more at [docs/downstream.md](https://github.com/melezhik/sparky/blob/master/docs/downstream.md)

## Sparky triggering protocol (STP)

Sparky Triggering Protocol allows to trigger jobs automatically by creating files in special format

Read more at [docs/stp.md](https://github.com/melezhik/sparky/blob/master/docs/stp.md)

## Job API

Job API allows to orchestrate multiple Sparky jobs

Read more at [docs/job_api.md](https://github.com/melezhik/sparky/blob/master/docs/job_api.md)

## Sparky plugins

Sparky plugins is way to extend Sparky jobs by writing plugins as Raku modules

Read more at [docs/plugins.md](https://github.com/melezhik/sparky/blob/master/docs/plugins.md)

## HTTP API

Sparky HTTP API allows execute Sparky jobs remotely over HTTP

Read more at [docs/api.md](https://github.com/melezhik/sparky/blob/master/docs/api.md)

## Security

### Authentication

Sparky web server _comes with_ two authentication protocols,
choose proper one depending on your requirements, see details
at [docs/auth.md](https://github.com/melezhik/sparky/blob/master/docs/auth.md)

### ACL

Sparky ACL allows to create access control lists to manage role based access to Sparky resources, see [docs/acl.md](https://github.com/melezhik/sparky/blob/master/docs/acl.md)

## Databases support

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

To trigger Sparky job in terminal use `sparky-runner.raku` cli:

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
