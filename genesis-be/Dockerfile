FROM debian:stretch-slim

ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GOLANG_VER 1.10.1
ENV GENESIS_BACKEND_BRANCH develop
ENV GENESIS_DEMO_APPS_URL https://raw.githubusercontent.com/GenesisKernel/apps/demo_apps_13/demo_apps.json

RUN apt-get update -y && \
    apt-get install -y supervisor curl git gnupg2 postgresql-client-9.6 \
    build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /go$GOLANG_VER.linux-amd64.tar.gz https://dl.google.com/go/go$GOLANG_VER.linux-amd64.tar.gz && tar xvf /go$GOLANG_VER.linux-amd64.tar.gz && mv /go /usr/local/ && find /go$GOLANG_VER.linux-amd64.tar.gz -delete

RUN go get -d github.com/GenesisKernel/go-genesis && cd /go/src/github.com/GenesisKernel/go-genesis && git checkout $GENESIS_BACKEND_BRANCH && go get github.com/GenesisKernel/go-genesis && mkdir -p /genesis-back/bin && git checkout | sed -E -n -e "s/^([^']+)'([^']+)'/\2/p" | sed -E -n "s/origin\/([^.]+)\./\1/p" > /genesis-back/bin/go-genesis.git_branch && git log --pretty=format:'%h' -n 1 > /genesis-back/bin/go-genesis.git_commit && mkdir -p /genesis-back/data/node1 && mv $GOPATH/bin/go-genesis /genesis-back/bin/go-genesis && rm -rf /go

RUN mkdir /genesis-apps && \
    echo -n "$GENESIS_DEMO_APPS_URL" > /genesis-apps/demo_apps.url
ADD $GENESIS_DEMO_APPS_URL /genesis-apps/demo_apps.json

RUN git clone https://github.com/blitzstern5/genesis-scripts /genesis-scripts

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-pip && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN pip3 install -r /genesis-scripts/requirements.txt

RUN apt-get remove -y build-essential && apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY supervisor/supervisord.conf /etc/supervisor/

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
