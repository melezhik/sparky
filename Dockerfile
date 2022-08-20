FROM ghcr.io/jj/raku-zef-gha:latest
RUN raku --version
USER root
RUN apk update && apk add openssl bash curl wget perl openssl-dev sqlite sqlite-dev sudo
RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN addgroup raku wheel
USER raku
RUN sudo echo
RUN echo OK && zef install --/test https://github.com/melezhik/Sparrow6.git
RUN echo OK && zef install --/test https://github.com/melezhik/sparrowdo.git
RUN echo OK && zef install --/test https://github.com/melezhik/Tomtit.git
RUN echo OK && zef install --/test https://github.com/melezhik/Tomty.git
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
RUN zef install --/test Digest
RUN zef install --/test Cro::TLS
RUN zef install --/test Log::Timeline
RUN zef install --/test Text::Markdown
RUN zef install --/test Terminal::ANSIColor
RUN zef install --/test Base64
RUN zef install --/test Digest::SHA1::Native
RUN zef install --/test Crypt::Random
RUN zef install --/test https://github.com/melezhik/sparky.git --verbose
RUN echo OK && zef install --/test https://github.com/melezhik/sparky-job-api.git
RUN git clone https://github.com/melezhik/sparky.git Sparky
WORKDIR Sparky
RUN raku db-init.raku
EXPOSE 4000
RUN cp -r examples/hello-world/ /home/raku/.sparky/projects/
ENTRYPOINT nohup sparkyd 2>&1 & cro run

