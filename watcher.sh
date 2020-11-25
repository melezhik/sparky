set -x
set -e

if ps uax|grep bin/sparky-web.raku|grep -v grep -q; then
  echo "sparky-web already running"
else
  cd ~/projects/sparky
  export SPARKY_HTTP_ROOT="/sparky"
  export SPARKY_ROOT=/home/rakudist/projects/RakuDist/sparky
  export BAILADOR=host:0.0.0.0,port:5000
  nohup raku bin/sparky-web.raku > sparky-web.log &
fi
