#! /usr/bin/env bash

### Configuration ### begin ###

VERSION="0.1.1"
SED_E="sed -E"

DB_PORT=15432
CF_PORT=18100
WEB_PORT_SHIFT=8300
CLIENT_PORT_SHIFT=17300

CONT_DB_PORT=5432
CONT_CF_PORT=8000
CONT_WEB_PORT_SHIFT=80
CONT_CLIENT_PORT_SHIFT=7000

DOWNLOADS_DIR='$HOME/Downloads' # !!! USE SINGLE QUOTES HERE !!!
APPS_DIR='$HOME/Applications' # !!! USE SINGLE QUOTES HERE !!!

DOCKER_APP_NAME="Docker"
DOCKER_DMG_DL_URL="https://download.docker.com/mac/stable/Docker.dmg"
DOCKER_DMG_BASENAME="$(basename "$(echo "$DOCKER_DMG_DL_URL" | $SED_E -n 's/^(.*\.dmg)(\?[^?]*)?$/\1/gp')")"
DOCKER_MAC_APP_DIR_SIZE_M=1136 # to update run 'du -sm /Applications/Docker.app'
DOCKER_MAC_APP_DIR="/Applications/Docker.app"
DOCKER_MAC_APP_BIN="/Applications/Docker.app/Contents/MacOS/Docker"

CLIENT_APP_NAME="Genesis"
CLIENT_DMG_DL_URL="https://www.dropbox.com/s/y9yvi3zk8ovpbh5/Genesis-0.4.1.dmg?dl=1"
CLIENT_DMG_BASENAME="$(basename "$(echo "$CLIENT_DMG_DL_URL" | $SED_E -n 's/^(.*\.dmg)(\?[^?]*)?$/\1/gp')")"
CLIENT_MAC_APP_DIR_SIZE_M=248 # to update run 'du -sm /Applications/Genesis.app'
CLIENT_MAC_APP_DIR="/Applications/Genesis.app"
CLIENT_MAC_APP_BIN="/Applications/Genesis.app/Contents/MacOS/Genesis"
CLIENT_APPIMAGE_DL_URL="https://www.dropbox.com/s/8n8rvm4dtx8agef/genesis-front-0.4.0-x86_64.AppImage?dl=1"
CLIENT_APPIMAGE_BASENAME="$(basename "$(echo "$CLIENT_APPIMAGE_DL_URL" | $SED_E -n 's/^(.*\.AppImage)(\?[^?]*)?$/\1/gp')")"

BF_CONT_NAME="genesis-bf"
BF_CONT_IMAGE="str16071985/genesis-bf:$VERSION"
BF_CONT_BUILD_DIR="genesis-bf"
TRY_LOCAL_BF_CONT_NAME_ON_RUN="yes"

DB_CONT_NAME="genesis-db"
DB_CONT_IMAGE="str16071985/genesis-db:$VERSION"
DB_CONT_BUILD_DIR="genesis-db"
TRY_LOCAL_DB_CONT_NAME_ON_RUN="yes"

CF_CONT_NAME="genesis-cf"
CF_CONT_IMAGE="str16071985/genesis-cf:$VERSION"
CF_CONT_BUILD_DIR="genesis-cf"
#CF_CONT_NAME="genesis-cf2"
#CF_CONT_IMAGE="str16071985/genesis-cf2"
#CF_CONT_BUILD_DIR="genesis-cf2"
TRY_LOCAL_CF_CONT_NAME_ON_RUN="yes"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTENV_PATH="$SCRIPT_DIR/.env"

### Configuration #### end ####


### .env ### begin ###

[ -e "$DOTENV_PATH" ] && . "$DOTENV_PATH"

### .env #### end ####


### OS ### begin ###

get_os_type() {
    case "$OSTYPE" in
        linux*)   echo "linux" ;;
        darwin*)  echo "mac" ;; 
        win*)     echo "windows" ;;
        cygwin*)  echo "cygwin" ;;
        bsd*)     echo "bsd" ;;
        solaris*) echo "solaris" ;;
        *)        echo "unknown" ;;
    esac
}

get_linux_dist() {
    local arch; arch=$(uname -m)
    local kernel; kernel=$(uname -r)
    local dist
    if [ -n "$(command -v lsb_release)" ]; then
        dist=$(lsb_release -is)
    elif [ -f "/etc/os-release" ]; then
        dist=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g' | tr -d '="')
    elif [ -f "/etc/debian_version" ]; then
        dist="Debian $(cat /etc/debian_version)"
    elif [ -f "/etc/redhat-release" ]; then
        dist=$(cat /etc/redhat-release)
    else
        dist="$(uname -s) $(uname -r)"
    fi
    if [ "$(cat /etc/issue | head -1 | awk {'print $2'})" = "Mint" ]; then
        echo "mint"
    else
        [ -n "$dist" ] && echo "$dist"
    fi
}

is_root() {
    [ "$EUID" -eq 0 ] && return 0 || return 1
}

check_run_as_root() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux)
            is_root;
            if [ $? -ne 0 ]; then
                echo "Please run with sudo or as root" 
                exit 20
            fi
            ;;
        mac)
            is_root;
            if [ $? -eq 0 ]; then
                echo "Please run as regular user (don't use sudo)"
                exit 21
            fi
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            exit 23
            ;;
    esac
}

run_as_orig_user() {
    is_root;
    if [ $? -eq 0 ]; then
        local who_user; who_user="$(who -m | awk '{print $1}')"
        local orig_user
        if [ -n "$SUDO_USER" ]; then
            orig_user="$SUDO_USER"
        elif [ -n "$who_user" ]; then
            orig_user="$who_user"
        else
            orig_user=""
        fi
        if [ -n "$orig_user" ]; then
            cmd="su - $orig_user -c '$@'"
        else
            cmd="su - -c '$@'"
        fi
    else
        cmd="$@"
    fi
    eval "$cmd"
}

get_orig_user_homedir() {
    run_as_orig_user 'echo $HOME'
}

check_min_req() {
    local cmd; local cmds;
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux|mac)
            cmds="lsof curl sed awk grep cat"
            for cmd in $cmds; do
                [ -z "$(command -v $cmd)" ] \
                    && echo "Command '$cmd' not found" && return 1
            done
            ;;

        *)
            echo "Sorry, but $os_type is not supported yet"
            return 10
            ;;
    esac
}

check_proc() {
    [ -z "$1" ] && echo "Process name isn't set" && return 2
    [ -z "$(pgrep "$1")" ] \
        && echo "No process '$1'" && return 2
    echo "ok" && return 0
}

wait_proc() {
    local proc_name; proc_name="$1"
    local timeout_secs; [ -z "$2" ] && timeout_secs=15 || timeout_secs="$2"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Wait
