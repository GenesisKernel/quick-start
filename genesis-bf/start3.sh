#! /usr/bin/env bash

CLIENT_PORT_SHIFT=7000

setup_frontends() {
    local num; [ -z "$1" ] \
        && echo "The number of frontends isn't set" && return 1 \
        || num=$1
    [ -z "$2" ] && cps=$CLIENT_PORT_SHIFT || cps=$2

    local cnt; cnt=0; local c_port; local s
    for i in $(seq 1 $1); do
        c_port=$(expr $i + $cps)
        if [ $cnt -gt 0 ]; then
            s="$i"
            if [ ! -d /apla-front/build$i ]; then
                echo "Copying /apla-front/build to /apla-front/build$i ..."
                cp -r /apla-front/build /apla-front/build$i 
            fi
            sed "s/81/8$i/g" /etc/nginx/sites-available/default > /etc/nginx/sites-available/default$i
            sed -i -e "s/s1/s$i/g" /etc/nginx/sites-available/default$i
            sed -i -e "s/build/build$i/g" /etc/nginx/sites-available/default$i
            sed -i -e "s/access\.log/access$i.log/g" /etc/nginx/sites-available/default$i
            sed -i -e "s/errors\.log/errors$i.log/g" /etc/nginx/sites-available/default$i
        else
            s=""
        fi
        sed -r -i -e "s/(127.0.0.1:)([^\/]+)(\/)/\1$c_port\3/g" /apla-front/build$s/settings.json
        [ -e /etc/nginx/sites-enabled/default$s ] \
            && rm /etc/nginx/sites-enabled/default$s
        ln -s /etc/nginx/sites-available/default$s /etc/nginx/sites-enabled/default$s
        cnt=$(expr $cnt + 1)
    done
    supervisorctl reread && supervisorctl update && supervisorctl restart nginx
}

setup_frontends $1 $2
