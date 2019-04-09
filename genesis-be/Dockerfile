FROM debian:stretch-slim

ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GOLANG_VER 1.11.5
ENV NODEJS_SETUP_SCRIPT_URL https://deb.nodesource.com/setup_10.x
ENV BACKEND_GO_URL github.com/AplaProject/go-apla
ENV BACKEND_BRANCH 1.2.7
ENV BE_BIN_BASENAME go-apla
ENV FRONTEND_REPO_URL https://github.com/GenesisKernel/genesis-front
ENV FRONTEND_BRANCH v0.11.1
ENV SCRIPTS_REPO_URL https://github.com/blitzstern5/genesis-scripts
ENV SCRIPTS_BRANCH v0.2.5
ENV DEMO_APPS_URL https://github.com/GenesisKernel/apps/releases/download/v1.3.0/system.json

RUN set -ex; apt-get update -y && \
    mkdir -p /usr/share/man/man1 && mkdir -p /usr/share/man/man7 && \
    apt-get install -y --no-install-recommends sudo supervisor curl git gnupg2 \
    postgresql-client-9.6 build-essential ca-certificates && apt-get clean; \
    (rm -rf /var/lib/apt/lists/*; :)

RUN curl -L -o go$GOLANG_VER.linux-amd64.tar.gz https://dl.google.com/go/go$GOLANG_VER.linux-amd64.tar.gz && tar -C /usr/local -xzf go$GOLANG_VER.linux-amd64.tar.gz && rm go$GOLANG_VER.linux-amd64.tar.gz

RUN go get -d $BACKEND_GO_URL && cd /go/src/$BACKEND_GO_URL && git checkout $BACKEND_BRANCH && go get $BACKEND_GO_URL && mkdir -p /genesis-back/bin && git rev-parse --abbrev-ref HEAD  > /genesis-back/bin/$BE_BIN_BASENAME.git_branch && git rev-parse HEAD > /genesis-back/bin/$BE_BIN_BASENAME.git_commit && mkdir -p /genesis-back/data/node1 && mv $GOPATH/bin/$BE_BIN_BASENAME /genesis-back/bin/$BE_BIN_BASENAME && rm -rf /go

RUN mkdir /genesis-apps && \
    echo -n "$DEMO_APPS_URL" > /genesis-apps/demo_apps.url
ADD $DEMO_APPS_URL /genesis-apps/demo_apps.json

RUN git clone -b $SCRIPTS_BRANCH $SCRIPTS_REPO_URL /genesis-scripts
COPY scripts.config.sh /genesis-scripts/.env

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-pip && apt-get clean; (rm -rf /var/lib/apt/lists/*; :)
RUN pip3 install -U pip
RUN pip3 install setuptools wheel
RUN pip3 install -r /genesis-scripts/requirements.txt

RUN apt-get remove -y build-essential && apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY supervisor/supervisord.conf /etc/supervisor/

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
