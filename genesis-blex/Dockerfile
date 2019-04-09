FROM debian:stretch-slim

ENV BLEX_REPO_URL https://github.com/GenesisKernel/blockexplorer
ENV BLEX_BRANCH v0.3.3
ENV SCRIPTS_REPO_URL https://github.com/blitzstern5/genesis-scripts
ENV SCRIPTS_BRANCH v0.2.5

RUN set -ex; apt-get update -y && \
    mkdir -p /usr/share/man/man1 && mkdir -p /usr/share/man/man7 && \
    apt-get install -y --no-install-recommends supervisor curl git libssl-dev \
    postgresql-client-9.6 build-essential ca-certificates && apt-get clean; \
    (rm -rf /var/lib/apt/lists/*; :)

RUN git clone -b $BLEX_BRANCH $BLEX_REPO_URL /genesis-blex

RUN apt-get update -y && apt-get install -y --no-install-recommends python3 python3-dev python3-pip python3-venv virtualenvwrapper && apt-get clean; (rm -rf /var/lib/apt/lists/*; :)
RUN pip3 install -U pip
RUN pip3 install setuptools wheel
RUN pip3 install -r /genesis-blex/requirements.txt

RUN apt-get remove -y build-essential && apt-get autoremove -y && \
    apt-get clean; (rm -rf /var/lib/apt/lists/*; :)

RUN git clone -b $SCRIPTS_BRANCH $SCRIPTS_REPO_URL /genesis-scripts
COPY scripts.config.sh /genesis-scripts/.env
COPY config.py /genesis-blex/

#COPY start_blockexplorer.sh /
COPY supervisor/supervisord.conf /etc/supervisor/
#COPY supervisor/conf.d/blockexplorer.conf /etc/supervisor/conf.d/

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
