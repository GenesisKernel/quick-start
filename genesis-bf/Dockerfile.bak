FROM yarnpkg/node-yarn

ENV GOLANG_VER 1.10
ENV GENESIS_FRONT_BRANCH tags/v0.6.1
ENV GENESIS_BACKEND_BRANCH release
ENV GENESIS_DEMO_APPS_URL https://raw.githubusercontent.com/GenesisKernel/apps/demo_apps_11/demo_apps.json

RUN apt-get update -y && apt-get install nginx git wget supervisor postgresql-client-9.4 -y && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -L -o /go$GOLANG_VER.linux-amd64.tar.gz https://dl.google.com/go/go$GOLANG_VER.linux-amd64.tar.gz && tar xvf /go$GOLANG_VER.linux-amd64.tar.gz && mv /go /usr/local/ && find /go$GOLANG_VER.linux-amd64.tar.gz -delete
ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN go get -d github.com/GenesisKernel/go-genesis && cd /go/src/github.com/GenesisKernel/go-genesis && git checkout $GENESIS_BACKEND_BRANCH && go get github.com/GenesisKernel/go-genesis && mkdir /apla && git checkout | sed -E -n -e "s/^([^']+)'([^']+)'/\2/p" | sed -E -n "s/origin\/([^.]+)\./\1/p" > /apla/go-apla.git_branch && git log --pretty=format:'%h' -n 1 > /apla/go-apla.git_commit && mkdir -p /s/s1 && mv $GOPATH/bin/go-genesis /apla/go-apla && rm -rf /go
RUN git clone --recursive https://github.com/GenesisKernel/genesis-front apla-front && cd /apla-front && git checkout $GENESIS_FRONT_BRANCH && git pull origin $GENESIS_FRONT_BRANCH && git branch | sed -E -n 's/.* (v[0-9a-zA-Z\-\.\_]+)\)/\1/p' > /apla-front.git_branch && git log --pretty=format:'%h' -n 1 > /apla-front.git_commit && yarn install && yarn build && find /apla-front -maxdepth 1 -mindepth 1 -not -name 'build*' -exec rm -rf {} \;
COPY settings.json /apla-front/build/
COPY apla-scripts /apla-scripts

RUN echo -n "$GENESIS_DEMO_APPS_URL" > /apla-scripts/demo_apps.url
ADD $GENESIS_DEMO_APPS_URL /apla-scripts/demo_apps.json

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-pip && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN pip3 install -r /apla-scripts/requirements.txt
COPY supervisord.d /etc/supervisord.d
COPY supervisor.conf /etc/
COPY nginx/default /etc/nginx/sites-available/default
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY start.sh /
COPY start2.sh /
COPY start3.sh /
COPY import_demo_apps.sh /
COPY go_apla /
COPY fullnodes.sh /
COPY upkeys.sh /
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor.conf"]
