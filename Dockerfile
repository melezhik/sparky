FROM ghcr.io/jj/raku-zef-gha:latest
USER root
#RUN adduser -D -s /bin/bash sparky
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN addgroup raku wheel
RUN apk update && apk add openssl bash curl wget perl openssl-dev sqlite sqlite-dev
USER raku
RUN zef install --/test https://github.com/melezhik/Sparrow6.git
RUN zef install --/test https://github.com/melezhik/sparrowdo.git
RUN zef install --/test https://github.com/melezhik/sparky-job-api.git
RUN zef install cro --/test
RUN zef install --/test https://github.com/melezhik/sparky.git
RUN git clone https://github.com/melezhik/sparky.git Sparky
WORKDIR Sparky
RUN raku db-init.raku
EXPOSE 4000
RUN cp -r examples/hello-world/ /home/raku/.sparky/projects/
ENTRYPOINT nohup sparkyd 2>&1 & cro run

