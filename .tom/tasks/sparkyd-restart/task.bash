set -e

sparman  worker stop

sparman --env SPARKY_TIMEOUT=10 worker start
