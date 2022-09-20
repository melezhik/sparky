FROM alpine:latest
ENV PATH="/home/raku/.raku/bin:/opt/rakudo-pkg/bin:${PATH}"
RUN apk update && apk add openssl bash curl wget perl openssl-dev sqlite sqlite-dev sudo git
RUN apk add --no-cache bash
RUN curl -1sLf \
  'https://dl.cloudsmith.io/public/nxadm-pkgs/rakudo-pkg/setup.alpine.sh' \
  | bash 
RUN apk add rakudo-pkg
RUN adduser -D -h /home/raku -s /bin/bash -G wheel raku
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN addgroup raku wheel
RUN sudo echo
USER raku
RUN git clone https://github.com/ugexe/zef.git /tmp/zef && \
cd /tmp/zef && \
raku -I. bin/zef install . --/test --install-to=home
RUN zef update
RUN zef install --/test JSON::Unmarshal 
RUN zef install --/test IO::Socket::Async::SSL
RUN zef install --/test JSON::Fast
RUN zef install --/test OO::Monitors                      
RUN zef install --/test Shell::Command
RUN zef install --/test Docker::File
RUN zef install --/test File::Ignore
RUN zef install --/test DBIish::Pool
RUN zef install --/test JSON::JWT
RUN zef install --/test HTTP::HPACK
RUN sudo apk add build-base libffi-dev
RUN zef install --/test Digest
RUN zef install --/test Cro::TLS
RUN zef install --/test Log::Timeline
RUN zef install --/test Text::Markdown
RUN zef install --/test Terminal::ANSIColor
RUN zef install --/test Base64
RUN zef install --/test Digest::SHA1::Native
RUN zef install --/test Crypt::Random
RUN zef install --/test IO::Socket::SSL
RUN echo OK zef install --/test https://github.com/melezhik/Sparrow6.git
RUN echo OK && zef install --/test https://github.com/melezhik/sparrowdo.git
RUN echo OK && zef install --/test https://github.com/melezhik/Tomtit.git
RUN echo OK && zef install --/test https://github.com/melezhik/Tomty.git
RUN echo OK3 && zef install --/test --force-install https://github.com/melezhik/sparky-job-api.git
RUN echo OK2 && zef install --/test --force-install https://github.com/melezhik/sparky.git --verbose
RUN ls -l && git clone https://github.com/melezhik/sparky.git /home/raku/Sparky
WORKDIR /home/raku/Sparky
RUN ls -l && raku db-init.raku
EXPOSE 4000
RUN cp -r examples/hello-world/ /home/raku/.sparky/projects/
ENTRYPOINT nohup sparkyd 2>&1 & cro run
