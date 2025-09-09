# Cli

Command line client for Sparky

## Trigger jobs

To trigger Sparky job in terminal use `sparky-runner` cli:

```bash
$ sparky-runner --dir=/home/user/.sparky/projects/teddy-bear-app
```

Or just:

```bash
$ cd ~/.sparky/projects/teddy-bear-app && sparky-runner
```

## Sparky runtime parameters

Runtime parameters could be overridden by command line ( `--root`, `--work-root` )

### root directory

Directory where scheduler looks for job scenarios, by default:

```bash
~/.sparky/projects/
```

###  work directory

Directory where scheduler keeps internal jobs data:

```bash
~/.sparky/work
```
