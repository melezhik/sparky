# Sparman

Sparman is a cli to run and configure Sparky components:

- sparkyd (aka sparky worker)

- web UI (aka sparky worker UI)

# API

## Sparky Worker

Sparky worker is a background process performing all SparrowCI tasks execution

```bash
sparman.raku worker start
sparman.raku worker stop
sparman.raku worker status
```

## Sparky Worker UI

Sparky worker UI allows to read worker reports and manage worker jobs. This
is intended for SparrowCI operations people

```bash
sparman.raku worker_ui start
sparman.raku worker_ui stop
sparman.raku worker_ui status
```

## Pass environment variables

To pass environmental variables to services, use `--env var=val,var2=val ...` notation.

For example, to set worker polling timeout to 10 seconds and set SPARROWCI_HOST:

```bash
sparman.raku --env SPARKY_TIMEOUT=10,SPARROWCI_HOST=http://127.0.0.1:2222 worker start
```

## Logs

Logs are available at the following locations:

Sparky Woker UI - `~/.sparky/sparky-web.log`

Sparky Woker - `~/.sparky/sparkyd.log `

