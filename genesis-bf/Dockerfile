FROM yarnpkg/node-yarn

ENV GENESIS_APPS_DEMO_PAGE_URL https://raw.githubusercontent.com/GenesisKernel/apps/0.9/demo_page.json

RUN apt-get update -y && apt-get install nginx git wget supervisor postgresql-client-9.4 -y && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -L -o /go1.9.4.linux-amd64.tar.gz https://dl.google.com/go/go1.9.4.linux-amd64.tar.gz && tar xvf /go1.9.4.linux-amd64.tar.gz && mv /go /usr/local/ && find /go1.9.4.linux-amd64.tar.gz -delete
ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN go get -d github.com/GenesisKernel/go-genesis && cd /go/src/github.com/GenesisKernel/go-genesis && git checkout release && go get github.com/GenesisKernel/go-genesis && mkdir /apla && mkdir -p /s/s1 && mv $GOPATH/bin/go-genesis /apla/go-apla && rm -rf /go
RUN git clone https://github.com/GenesisKernel/genesis-front apla-front && cd /apla-front && git checkout tags/v0.4.1-c && yarn install && yarn build && find /apla-front -maxdepth 1 -mindepth 1 -not -name 'build*' -exec rm -rf {} \;
COPY settings.json /apla-front/build/
COPY apla-scripts /apla-scripts

RUN echo -n "$GENESIS_APPS_DEMO_PAGE_URL" > /apla-scripts/demo_page.url
ADD $GENESIS_APPS_DEMO_PAGE_URL /apla-scripts

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-pip && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN pip3 install -r /apla-scripts/requirements.txt
COPY supervisord.d /etc/supervisord.d
COPY supervisor.conf /etc/
COPY nginx/default /etc/nginx/sites-available/default
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY start.sh /
COPY start2.sh /
COPY start3.sh /
COPY import_demo_page.sh /
COPY go_apla /
COPY fullnodes.sh /
COPY upkeys.sh /
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor.conf"]
