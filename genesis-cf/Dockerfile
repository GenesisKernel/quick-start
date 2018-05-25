FROM debian:stretch-slim

ENV CENTRIFUGO_VERSION 1.7.9

ENV CENTRIFUGO_SHA256 da293d464b2b6b62fb8972c6a9d6b24d71fe93212c8f1e294eb61fa2e8a24c16

ENV CENTRIFUGO_DOWNLOAD https://github.com/centrifugal/centrifugo/releases/download/v$CENTRIFUGO_VERSION/centrifugo-$CENTRIFUGO_VERSION-linux-amd64.zip

RUN apt update -y && \
    apt install -y curl unzip --no-install-recommends && \
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
