#! /usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
USER=nobody
GROUP=nogroup
NAME="blockexplorer"
PROJ_DIR="/genesis-blex"
[ ! -e "$PROJ_DIR" ] && echo "Project dir $PROJ_DIR doesn't exist" && exit 1
echo "PROJ_DIR: $PROJ_DIR"
echo "ENV_DIR: $ENV_DIR"
echo "USER: $USER"
echo "GROUP: $GROUP"
echo "NAME: $NAME"
NUM_WORKERS=3
echo "Starting $NAME as `whoami`"

#source "$ENV_DIR/bin/activate"
cd $PROJ_DIR && exec python3 run-simple.py
