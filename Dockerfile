FROM alpine:latest
ENV PATH="/home/raku/.raku/bin:/opt/rakudo-pkg/bin:${PATH}"
RUN apk update && apk add openssl bash curl wget perl openssl-dev sqlite sqlite-dev sudo git build-base libffi-dev

RUN apk add --no-cache --wait 120 -u --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community zef raku-sparrow6 raku-sparky-job-api

RUN adduser -D -h /home/raku -s /bin/bash -G wheel raku
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN addgroup raku wheel
RUN sudo echo

USER raku
RUN zef install --/test https://github.com/melezhik/sparky.git
RUN zef install --/test --force-install https://github.com/melezhik/sparky.git
RUN git clone https://github.com/melezhik/sparky.git /home/raku/Sparky
WORKDIR /home/raku/Sparky
RUN ls -l && raku db-init.raku

EXPOSE 4000
RUN cp -r examples/hello-world/ /home/raku/.sparky/projects/
ENTRYPOINT nohup sparkyd 2>&1 1>/tmp/out.log & cro run
