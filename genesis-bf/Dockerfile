FROM yarnpkg/node-yarn
RUN apt-get update -y && apt-get install nginx git wget supervisor postgresql-client-9.4 -y && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -L -o /go1.9.2.linux-amd64.tar.gz https://dl.google.com/go/go1.9.2.linux-amd64.tar.gz && tar xvf /go1.9.2.linux-amd64.tar.gz && mv /go /usr/local/ && find /go1.9.2.linux-amd64.tar.gz -delete
ENV GOPATH /go
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#RUN go get github.com/AplaProject/go-apla && mkdir /apla && mkdir -p /s/s1 && mv $GOPATH/bin/go-apla /apla
RUN git clone -b release https://github.com/AplaProject/go-apla.git /go-apla-src && cd /go-apla-src && git checkout release && go build && mkdir /apla && mkdir -p /s/s1 && mv go-apla /apla && rm -rf /go-apla-src
RUN git clone https://github.com/AplaProject/apla-front.git && cd /apla-front && yarn install && yarn build && find /apla-front -maxdepth 1 -mindepth 1 -not -name 'build*' -exec rm -rf {} \;
COPY settings.json /apla-front/build/
RUN git clone https://github.com/AplaProject/apla-tests.git /apla-tests
RUN apt-get update -y && apt-get -y install python3 python3-pip && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN pip3 install -r /apla-tests/requirements.txt
COPY supervisord.d /etc/supervisord.d
COPY supervisor.conf /etc/
COPY nginx/default /etc/nginx/sites-available/default
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY start.sh /
COPY start2.sh /
COPY start3.sh /
COPY go_apla /
COPY fullnodes.sh /
COPY upkeys.sh /
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor.conf"]
