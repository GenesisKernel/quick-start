#! /usr/bin/env bash

GO_APLA_LOG_DIR="/var/log/go-apla"

[ ! -d "$GO_APLA_LOG_DIR" ] \
    && echo "Creating go-apla log directory '$GO_APLA_LOG_DIR' ..." \
    && mkdir -p "$GO_APLA_LOG_DIR"

for i in $(seq 2 $1); do

    if [ -f "/s/s$i/apla.pid" ]; then
        rm /s/s$i/apla.pid
    fi

    if [ ! -d "/s/s$i" ]; then
        mkdir /s/s$i
    fi

    if [ $1 == 1 ]; then
        echo "1 started"
    else
        cd /apla && ./go-apla -workDir=/s/s$i -tcpPort=701$1 -httpPort=700$i -dbHost=genesis-db -dbPort=5432 -dbName=eg$i -dbUser=postgres -dbPassword=111111 --configPath /dev/null -initDatabase=1 -generateFirstBlock=1 -noStart=1 && echo "go-apla in noStart mode finished"

        keyID2=`cat /s/s$i/KeyID`
    fi
    
    sed 's/INSTANCE/'$i'/g' /go_apla > /etc/supervisord.d/go_apla$i.conf
    sed -i -e 's/keyID2/'$keyID2'/g' /etc/supervisord.d/go_apla$i.conf

done

