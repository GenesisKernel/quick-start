FROM debian:stretch-slim

ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GOLANG_VER 1.10.3
ENV BACKEND_GO_URL github.com/GenesisKernel/go-genesis
ENV BACKEND_BRANCH master
ENV SCRIPTS_REPO_URL https://github.com/blitzstern5/genesis-scripts
ENV SCRIPTS_BRANCH develop
ENV DEMO_APPS_URL https://raw.githubusercontent.com/GenesisKernel/apps/master/quick-start/quick-start.json

RUN apt-get update -y && \
    apt-get install -y supervisor curl git gnupg2 postgresql-client-9.6 \
    build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /go$GOLANG_VER.linux-amd64.tar.gz https://dl.google.com/go/go$GOLANG_VER.linux-amd64.tar.gz && tar xvf /go$GOLANG_VER.linux-amd64.tar.gz && mv /go /usr/local/ && find /go$GOLANG_VER.linux-amd64.tar.gz -delete

RUN go get -d $BACKEND_GO_URL && cd /go/src/$BACKEND_GO_URL && git checkout $BACKEND_BRANCH && go get $BACKEND_GO_URL && mkdir -p /genesis-back/bin && git checkout | sed -E -n -e "s/^([^']+)'([^']+)'/\2/p" | sed -E -n "s/origin\/([^.]+)\./\1/p" > /genesis-back/bin/go-genesis.git_branch && git log --pretty=format:'%h' -n 1 > /genesis-back/bin/go-genesis.git_commit && mkdir -p /genesis-back/data/node1 && mv $GOPATH/bin/go-genesis /genesis-back/bin/go-genesis && rm -rf /go

RUN mkdir /genesis-apps && \
    echo -n "$DEMO_APPS_URL" > /genesis-apps/demo_apps.url
ADD $DEMO_APPS_URL /genesis-apps/demo_apps.json

RUN git clone -b $SCRIPTS_BRANCH $SCRIPTS_REPO_URL /genesis-scripts

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-pip && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN pip3 install -r /genesis-scripts/requirements.txt

RUN apt-get remove -y build-essential && apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY supervisor/supervisord.conf /etc/supervisor/

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
