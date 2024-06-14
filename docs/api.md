# HTTP API

Sparky HTTP API allows execute Sparky jobs remotely over HTTP

## Trigger Sparky job

```http
POST /build/project/$project
```

Returns `$key` - unique build identification ( aka Sparky Job ID )

## Trigger job with parameters

```http
POST /build-with-tags/project/$project @json
```

For example:

Request data - `request.json`:

```json
{ 
  "description" : "test build",
  "tags" : "message=hello,from=Sparky"
}
```

Request via curl:

```bash
curl -k  -H "Content-Type: application/json" \
--data "@request.json" \
https://127.0.0.1:4000/build-with-tags/project/hello-world
```

Will trigger a job `hello-world`, with named parameters `message` and `from`.

Parameters are handled within Sparky scenario as:

```raku
my $message = tags()<message>;
my $from = tags()<from>;
```

## Job status

Get job status - status of the last executed build:

```http
GET /status/$project/$key
```

Returns `$status`:

* `0` - build is running

* `-1` - build failed

* `1` - build finished successfully

* `-2` - unknown state ( build does not exist or is placed in a queue )

## Badges

Get job badge - image with status of the last executed build

```http
GET /badge/$project
```

## Job report

Get build report in raw text format

```http
GET /report/raw/$project/$key
```
