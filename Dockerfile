FROM ghcr.io/jj/raku-zef-gha:latest
USER root
RUN apk update && apk add openssl bash curl wget perl openssl-dev sqlite sqlite-dev
#USER raku
RUN zef install --verbose File::Find && raku -e 'use File::Find' 
RUN zef install --/test https://github.com/melezhik/Sparrow6.git
RUN zef install --/test https://github.com/melezhik/sparrowdo.git
RUN zef install --/test https://github.com/melezhik/sparky-job-api.git
#USER root
#USER raku
RUN zef install Cro::TLS --/test
RUN zef install --/test https://github.com/melezhik/sparky.git  && echo OK2
RUN git clone https://github.com/melezhik/sparky.git Sparky
#USER root
RUN apk add bash curl wget perl
#USER raku
WORKDIR Sparky
RUN raku db-init.raku
EXPOSE 4000
RUN cp -r examples/hello-world/ /home/raku/.sparky/projects/
ENTRYPOINT nohup sparkyd 2>&1 & cro run

