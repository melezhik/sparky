# Env

Sparky Environment variables

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