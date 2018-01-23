#!/bin/bash
case $1 in
  create)
    sudo -u postgres createdb -E "UTF-8" -O $2 $3
    ;;
esac

