# Glossary

Some useful glossary

# Job aka Sparky aka Sparky project

Raku scenario gets executed on some event and does some useful job

# Sparky scenario

Implimentation of Sparky job written on Raku

# Build

A specific instance of Sparky job. Usually reports are visibale though UI and
might have some artifacts

# Report

Log of Sparky job exececution

# Artifact

Some byproducts ( technucally are files) attached to a build and visible through UI

# UI aka Sparky web UI

Web application to run Sparky jobs and get their reports

# Sparrowdo

A client to run Sparky jobs on (remote) hosts and docker containers

# Sparrow

Underlying automation framework to execute Sparky job

# sparky.yaml

YAML defintion of Sparky job meta information, like input patrameters, UI controls,
triggering logic, etc. Every Sparky job has a sparky.yaml file


# root directory

Directory where scheduller looks for job scenarios, by default:

```bash
~/.sparky/projects/
```

#  work directory

Directory where scheduller keeps internal jobs data:

```bash
~/.sparky/work
```