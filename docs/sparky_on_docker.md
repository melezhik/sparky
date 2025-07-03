# Sparky on docker

How to run Sparky on docker

## Build docker image

```bash
$ git clone https://github.com/melezhik/sparky.git
$ cd sparky/
$ docker build . -t local/sparky
```

## Prepare Sparky projects local storage

```bash
$ sudo apt-get install sqlite3
$ git clone https://github.com/melezhik/sparky.git
$ cd sparky && zef install .
$ raku db-init.raku
```

This storage persists on host file system and remains across Sparky container restarts

## Run sparky 

```
docker run -it  -p 4000:4000 -v ~/.sparky/:/home/raku/.sparky local/sparky:latest 
```

Go to http://localhost:4000


## Add new project

To add new project just copy project into local storage: 


```bash
cp -r /path/to/project/hello-world/ /home/raku/.sparky/projects/
```
