# Glossary

Some useful glossary

# Job aka Sparky aka Sparky project

Raku scenario gets executed on some event and does some useful job

# Sparky scenario

Implementation of Sparky job written on Raku

# Build

A specific instance of Sparky job. Usually reports are visible though UI and
might have some artifacts

# Report

Log of Sparky job execution

# Artifact

Some byproducts ( technically are files) attached to a build and visible through UI

# UI aka Sparky web UI

Web application to run Sparky jobs and get their reports

# Sparrowdo

A client to run Sparky jobs on (remote) hosts and docker containers

# Sparrow

Underlying automation framework to execute Sparky job

# sparky.yaml

YAML definition of Sparky job meta information, like input parameters, UI controls,
triggering logic, etc. Every Sparky job has a sparky.yaml file


# root directory

Directory where scheduler looks for job scenarios, by default:

```bash
~/.sparky/projects/
```

#  work directory

Directory where scheduler keeps internal jobs data:

```bash
~/.sparky/work
```
