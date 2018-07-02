FROM debian:stretch-slim

ENV CENTRIFUGO_VERSION 1.8.0

ENV CENTRIFUGO_SHA256 ed68b83a7d0a1df1355fceb594a0786a3b0c25b5ed997edf8c55c5f59f13d472

ENV CENTRIFUGO_DOWNLOAD https://github.com/centrifugal/centrifugo/releases/download/v$CENTRIFUGO_VERSION/centrifugo-$CENTRIFUGO_VERSION-linux-amd64.zip

RUN apt update -y && \
    apt install -y curl unzip ca-certificates --no-install-recommends && \
    curl -sSL "$CENTRIFUGO_DOWNLOAD" -o /tmp/centrifugo.zip && \
    echo "${CENTRIFUGO_SHA256}  /tmp/centrifugo.zip" | sha256sum -c - && \
    unzip -jo /tmp/centrifugo.zip -d /tmp/ && \
    apt remove -y unzip && \
    apt autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    mv /tmp/centrifugo /usr/bin/centrifugo && \
    rm -f /tmp/centrifugo.zip && \
    echo "centrifugo - nofile 65536" >> /etc/security/limits.d/centrifugo.nofiles.conf

RUN groupadd -r centrifugo && useradd -r -g centrifugo centrifugo

RUN mkdir /centrifugo && chown centrifugo:centrifugo /centrifugo && \
    mkdir /var/log/centrifugo && chown centrifugo:centrifugo /var/log/centrifugo

VOLUME ["/centrifugo", "/var/log/centrifugo"]

WORKDIR /centrifugo

USER centrifugo

COPY config.json /centrifugo/config.json

CMD ["centrifugo", "--config", "/centrifugo/config.json"]
