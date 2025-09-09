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
$ sparkyd # run Sparky daemon to trigger jobs
$ cro run # run Sparky CI UI to see job statuses and reports
$ nano ~/.sparky/projects/my-project/sparrowfile  # write a job scenario
$ firefox 127.0.0.1:4000 # run jobs and get reports
```

# Installation

```bash
$ sudo apt-get install sqlite3
$ git clone https://github.com/melezhik/sparky.git
$ cd sparky && zef install .
```

## Database initialization

Sparky requires a database to operate.

Run database initialization script to populate database schema:

```bash
$ raku db-init.raku
```

# Sparky components

Sparky comprises of several components:

* Jobs scheduler

* Jobs Definitions

* Jobs workers (including remote jobs)

* Jobs UI

* CLI

## Job scheduler

To run Sparky jobs scheduler (aka daemon) runs in console:

```bash
$ sparkyd
```

Scheduler logic:

* Sparky daemon traverses sub directories found at the project root directory.

* For every directory found initiate job run process invoking sparky worker ( `sparky-runner` ).

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
## Sparky Jobs UI

Sparky has a simple web UI to allow trigger jobs and get reports.

To run Sparky UI web application:

```bash
$ cro run
```

By default Sparky UI application listens on host `0.0.0.0`, port `4000`, 
to override these settings set  `SPARKY_HOST`, `SPARKY_TCP_PORT` 
in `~/sparky.yaml` configuration file:

```yaml
SPARKY_HOST: 127.0.0.1
SPARKY_TCP_PORT: 5000 
```

## Sparky jobs definitions

Sparky job needs a directory located at the sparky root directory:

```bash
$ mkdir ~/.sparky/projects/teddy-bear-app
```

To create a job scenario, create file named `sparrowfile` located in job directory.

Sparky uses pure [Raku](https://raku.org) for job syntax, for example:

```bash
$ nano ~/.sparky/projects/hello-world/sparrowfile
```

```raku
#!raku
say "hello Sparky!";
```

To allow job to be executed by scheduler one need to create `sparky.yaml` - yaml based
job definition, minimal form would be:

```bash
$ nano ~/.sparky/projects/hello-world/sparky.yaml
```

```yaml
allow_manual_run: true
```

## Extending scenarios with Sparrow automation framework

To extend core functions, Sparky is fully integrated with [Sparrow](https://github.com/melezhik/Sparrow6) automation framework.

Here in example of job that uses Sparrow plugins, to build typical Raku project:

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

Repository of Sparrow plugins is available at [https://sparrowhub.io](https://sparrowhub.io)


## Systemd units

To install sparky UI, sparkyd systemd units:

```bash
$ sparrowdo --sparrowfile=utils/install-sparky-systemd.raku --localhost
```

## Sparky workers

Sparky uses [Sparrowdo](https://github.com/melezhik/sparrowdo) to launch jobs in three fashions:

* on localhost ( the same machine where Sparky is installed, default)
* on remote host with ssh
* docker container on localhost / remote machine 

```
/--------------------\                                             [ localhost ]
| Sparky on localhost| --> sparrowdo client --> job (sparrow) -->  [ container ]
\--------------------/                                             [ ssh host  ]
```

By default job scenarios get executed _on the same machine you run Sparky at_, 
to run jobs on _remote host_ set sparrowdo section in `sparky.yaml` file:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

```yaml
sparrowdo:
  host: '192.168.0.1'
  ssh_private_key: /path/to/ssh_private/key.pem
  ssh_user: sparky
  no_index_update: true
  sync: /tmp/repo
```

Follow [sparrowdo cli](https://github.com/melezhik/sparrowdo#sparrowdo-cli) documentation for `sparrowdo` configuration section explanation.

### Skip bootstrap

Sparrowdo client bootstrap might take some time. 

To disable bootstrap use  `bootstrap: false` option. 

Useful if sparrowdo client is already installed on target host.

```yaml
sparrowdo:
  bootstrap: false
```

### Purging old builds

To remove old job builds set `keep_builds` parameter in `sparky.yaml`:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

Put number of builds to keep:

```yaml
keep_builds: 10
```

That makes Sparky remove old builds and only keep last `keep_builds` builds.

### Run jobs by cron

To run Sparky jobs periodically, set `crontab` entry in sparky.yaml file.

For example, to run a job every hour at 30,50 or 55 minutes:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

```cron
crontab: "30,50,55 * * * *"
```

Follow [Time::Crontab](https://github.com/ufobat/p6-time-crontab) documentation on crontab entries format.

### Manual run

To trigger job manually from web UI, use `allow_manual_run`:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml
```

```yaml
allow_manual_run: true
```

### Trigger job by SCM changes

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

### Flappers protection mechanism 

Flapper protection mechanism kicks out SCM urls that are timeouted (certain amount of time) during git connection, from scheduling, this mechanism protects sparkyd worker from stalling.

To disable flappers protection mechanism, set `SPARKY_FLAPPERS_OFF` environment variable
or adjust `~/sparky.yaml` configuration file:

```yaml
worker:
  flappers_off: true
```

### Disable jobs

To prevent Sparky job from execution use `disable` option:

```bash
$ nano ~/.sparky/projects/teddy-bear-app/sparky.yaml

disabled: true
```

# Advanced topics

Following are advanced topics covering some cool Sparky features.

## Job UIs

Sparky UI DSL allows to grammatically describe UI for Sparky jobs
and pass user input into a scenario as variables.

Read more at [docs/ui.md](https://github.com/melezhik/sparky/blob/master/docs/ui.md)

## Downstream jobs

Downstream jobs get run after some _main_ job has finished.

Read more at [docs/downstream.md](https://github.com/melezhik/sparky/blob/master/docs/downstream.md)

## Sparky triggering protocol (STP)

Sparky triggering protocol allows to trigger jobs automatically by creating files in special format.

Read more at [docs/stp.md](https://github.com/melezhik/sparky/blob/master/docs/stp.md)

## Job API

Job API allows to orchestrate multiple Sparky jobs.

Read more at [docs/job_api.md](https://github.com/melezhik/sparky/blob/master/docs/job_api.md)

## Sparky plugins

Sparky plugins is way to extend Sparky jobs by writing reusable plugins as Raku modules.

Read more at [docs/plugins.md](https://github.com/melezhik/sparky/blob/master/docs/plugins.md)

## HTTP API

Sparky HTTP API allows execute Sparky jobs remotely over HTTP.

Read more at [docs/api.md](https://github.com/melezhik/sparky/blob/master/docs/api.md)

## Security

### Authentication

Sparky web server _comes with_ two authentication protocols,
choose proper one depending on your requirements.

Read more at [docs/auth.md](https://github.com/melezhik/sparky/blob/master/docs/auth.md)

### ACL

Sparky ACL allows to create access control lists to manage role based access to Sparky resources.

Read more at [docs/acl.md](https://github.com/melezhik/sparky/blob/master/docs/acl.md)

## Databases support

Sparky keeps it's data in database, by default it uses sqlite,
following databases are supported:

* SQLite
* MySQL/MariaDB
* PostgreSQL

Read more at [docs/database.md](https://github.com/melezhik/sparky/blob/master/docs/database.md)

## TLS Support

Sparky web server may run on TLS. To enable this add a couple of parameters to `~/sparky.yaml`

configuration file:

```
SPARKY_USE_TLS: true
tls:
 private-key-file: '/home/user/.sparky/certs/www.example.com.key'
 certificate-file: '/home/user/.sparky/certs/www.example.com.cert'
```

`SPARKY_USE_TLS` enables SSL mode and `tls` section has paths to ssl certificate ( key and certificate parts ).

# Additional topics

## Sparky on docker

How to run Sparky via docker container. See [docs/sparky_on_docker.md](docs/sparky_on_docker.md) document.

## Sparman

Sparman is a cli to ease SparrowCI management. See [docs/sparman.md](docs/sparman.md) document.

## Sparky cli

Sparky cli allows to trigger jobs in terminal.

Read more at [docs/cli.md](https://github.com/melezhik/sparky/blob/master/docs/cli.md)

## Sparky Environment variables

Use environment variables to tune Sparky configuration.

Read more at [docs/env.md](https://github.com/melezhik/sparky/blob/master/docs/env.md)

## Glossary

Some useful glossary.

Read more at [docs/glossary.md](https://github.com/melezhik/sparky/blob/master/docs/glossary.md)

## CSS

Sparky uses [Bulma](https://bulma.io/) as CSS framework for web UI.

## Sparky job examples

Examples of various Sparky jobs could be found at [examples/](https://github.com/melezhik/sparky/tree/master/examples) folder.

# See also

* [Cro](https://cro.services) - Raku Web Framework

* [Sparky-docker](https://github.com/melezhik/sparky-docker) - Run Sparky as Docker container

# Author

Alexey Melezhik
