FROM debian:stretch-slim

ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GOLANG_VER 1.10.3
ENV NODEJS_SETUP_SCRIPT_URL https://deb.nodesource.com/setup_8.x
ENV BACKEND_GO_URL github.com/GenesisKernel/go-genesis
ENV BACKEND_BRANCH 0.9.2
ENV FRONTEND_REPO_URL https://github.com/GenesisKernel/genesis-front
ENV FRONTEND_BRANCH v0.8.6-RC
ENV SCRIPTS_REPO_URL https://github.com/blitzstern5/genesis-scripts
ENV SCRIPTS_BRANCH 0.1.0
ENV DEMO_APPS_URL https://github.com/GenesisKernel/apps/releases/download/quick-start-0.9.15/quick-start.json

RUN set -ex; apt-get update -y && \
    mkdir -p /usr/share/man/man1 && mkdir -p /usr/share/man/man7 && \
    apt-get install -y --no-install-recommends supervisor curl git gnupg2 \
    postgresql-client-9.6 build-essential ca-certificates && apt-get clean; \
    (rm -rf /var/lib/apt/lists/*; :)

RUN curl -L -o /go$GOLANG_VER.linux-amd64.tar.gz https://dl.google.com/go/go$GOLANG_VER.linux-amd64.tar.gz && tar xvf /go$GOLANG_VER.linux-amd64.tar.gz && mv /go /usr/local/ && find /go$GOLANG_VER.linux-amd64.tar.gz -delete

RUN go get -d $BACKEND_GO_URL && cd /go/src/$BACKEND_GO_URL && git checkout $BACKEND_BRANCH && go get $BACKEND_GO_URL && mkdir -p /genesis-back/bin && git checkout | sed -E -n -e "s/^([^']+)'([^']+)'/\2/p" | sed -E -n "s/origin\/([^.]+)\./\1/p" > /genesis-back/bin/go-genesis.git_branch && git log --pretty=format:'%h' -n 1 > /genesis-back/bin/go-genesis.git_commit && mkdir -p /genesis-back/data/node1 && mv $GOPATH/bin/go-genesis /genesis-back/bin/go-genesis && rm -rf /go

RUN mkdir /genesis-apps && \
    echo -n "$DEMO_APPS_URL" > /genesis-apps/demo_apps.url
ADD $DEMO_APPS_URL /genesis-apps/demo_apps.json

RUN git clone -b $SCRIPTS_BRANCH $SCRIPTS_REPO_URL /genesis-scripts
COPY scripts.config.sh /genesis-scripts/.env

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-pip && apt-get clean; (rm -rf /var/lib/apt/lists/*; :)
RUN pip3 install setuptools
RUN pip3 install -r /genesis-scripts/requirements.txt

RUN apt-get remove -y build-essential && apt-get autoremove -y && \
    apt-get clean; (rm -rf /var/lib/apt/lists/*; :)

COPY supervisor/supervisord.conf /etc/supervisor/

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends nginx curl git gnupg2 && \
    apt-get clean; (rm -rf /var/lib/apt/lists/*; :)

RUN curl -sL $NODEJS_SETUP_SCRIPT_URL | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get remove -y cmdtest && \
    apt-get autoremove -y

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y --no-install-recommends yarn

RUN git clone --recursive $FRONTEND_REPO_URL genesis-front && cd /genesis-front && git checkout $FRONT_BRANCH && git pull origin $FRONT_BRANCH && git branch | sed -E -n 's/.* (v[0-9a-zA-Z\-\.\_]+)\)/\1/p' > /genesis-front.git_branch && git log --pretty=format:'%h' -n 1 > /genesis-front.git_commit && yarn install && yarn build && find /genesis-front -maxdepth 1 -mindepth 1 -not -name 'build*' -exec rm -rf {} \;
#RUN mkdir -p /genesis-front
#COPY genesis-front-build /genesis-front/build/
COPY genesis-front/settings.json /genesis-front/build/

RUN apt-get remove -y gnupg2 && \
    apt-get autoremove -y && \
    apt-get clean; (rm -rf /var/lib/apt/lists/*; :)

COPY supervisor/conf.d/nginx.conf /etc/supervisor/conf.d/
COPY nginx/default /etc/nginx/sites-available/default
COPY nginx/nginx.conf /etc/nginx/nginx.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
