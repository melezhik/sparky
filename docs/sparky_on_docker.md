# Sparky on docker

How to run Sparky on docker

## Build docker image

```bash
$ git clone https://github.com/melezhik/sparky.git sparky_src
$ cd sparky_src/
$ docker build . -t local/sparky
```

## Prepare Sparky local storage

```bash
$ sudo apt-get install sqlite3
$ cd sparky_src/
$ zef install --/test YAMLish DBIish Time::Crontab Data::Dump
# this command will create
# directory ~/.sparky
# with sparky sqlite database
# and some other internal
# data inside 
$ raku -I lib/ db-init.raku
```

This sparky local storage (~/.sparky directory) persists on host file system and remains across Sparky container restarts

## Run sparky 

```
# we run sparky docker container
# and mount sparky local storage
# inside running container

$ docker run -it  -p 4000:4000 -v ~/.sparky/:/home/raku/.sparky local/sparky:latest 
```

Go to http://localhost:4000


## Add new project

To add new project, just create a new directory inside local storage and copy/create all project data inside
this directory

```bash
$ mkdir ~/.sparky/projects/new-project
$ nano  ~/.sparky/projects/new-project/sparky.yaml
$ nano  ~/.sparky/projects/new-project/sparrowfile
```
