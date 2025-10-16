set -e

sparman  worker stop

sparman --env SPARKY_TIMEOUT=10 worker start

sparman  worker_ui stop

sparman  worker_ui start
