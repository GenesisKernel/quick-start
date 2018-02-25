#! /usr/bin/env bash

scripts_dir="/apla-scripts"
key=$(cat "/s/s1/KeyID")
prKey=$(cat "/s/s1/PrivateKey")
host="127.0.0.1"
httpPort=7001
dataPath="$scripts_dir/demo_apps.json"

python3 "$scripts_dir/import_demo_apps.py" "$prKey" "$host" "$httpPort" "$dataPath"
