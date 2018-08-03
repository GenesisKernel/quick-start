FROM debian:stretch-slim

ENV FRONTEND_REPO_URL https://github.com/GenesisKernel/genesis-front
ENV FRONTEND_BRANCH v0.8.6-RC
ENV NODEJS_SETUP_SCRIPT_URL https://deb.nodesource.com/setup_8.x

RUN apt-get update -y && \
    apt-get install -y nginx curl git gnupg2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -sL $NODEJS_SETUP_SCRIPT_URL | bash - && \
    apt-get install -y nodejs && \
    apt-get remove -y cmdtest && \
    apt-get autoremove -y

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn

RUN git clone --recursive $FRONTEND_REPO_URL genesis-front && cd /genesis-front && git checkout $FRONT_BRANCH && git pull origin $FRONT_BRANCH && git rev-parse --abbrev-ref HEAD > /genesis-front.git_branch && git rev-parse HEAD > /genesis-front.git_commit && yarn install && yarn build && find /genesis-front -maxdepth 1 -mindepth 1 -not -name 'build*' -exec rm -rf {} \;
COPY genesis-front/settings.json /genesis-front/build/

RUN apt-get remove -y gnupg2 && \
    apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["sh", "-c", "tail -f /dev/null"]
