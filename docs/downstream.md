# Downstream jobs

Downstream jobs get run after some _main_ job has finished.

One define job as downstream by referencing to downstream job in main job:

```yaml
# definition of main job here
# job named cleanup will be executed
# after the main job
downstream: cleanup
```

Downstream jobs could be chained, so one could defined downstream within another
downstream job. For more advanced and effective job orchestration consider
Sparky Job API - [docs/job_api.md](https://github.com/melezhik/sparky/blob/master/docs/job_api.md)
