#! /usr/bin/env bash

### Configuration ### begin ###

PREV_VERSION="0.6.1"
VERSION="0.6.2"
SED_E="sed -E"

GOLANG_VER="1.10.2"
GENESIS_BACKEND_BRANCH="develop"
#GENESIS_FRONT_BRANCH="tags/v0.6.1"
GENESIS_FRONT_BRANCH="master"
GENESIS_DEMO_APPS_URL="https://raw.githubusercontent.com/GenesisKernel/apps/demo_apps_14/demo_apps.json"

GENESIS_DB_NAME_PREFIX="genesis"

GENESIS_BE_ROOT="/genesis-back"
GENESIS_BE_ROOT_LOG_DIR="/var/log/go-genesis"
GENESIS_BE_ROOT_DATA_DIR="$GENESIS_BE_ROOT/data"
GENESIS_BE_BIN_DIR="$GENESIS_BE_ROOT/bin"
GENESIS_BE_BIN_BASENAME="go-genesis"
GENESIS_BE_BIN_PATH="$GENESIS_BE_BIN_DIR/$GENESIS_BE_BIN_BASENAME"

GENESIS_FE_SRC_DIR="/genesis-front"

GENESIS_SCRIPTS_DIR="/genesis-scripts"
GENESIS_APPS_DIR="/genesis-apps"

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
#DOCKER_DMG_DL_URL="https://download.docker.com/mac/stable/Docker.dmg"
DOCKER_DMG_DL_URL="https://download.docker.com/mac/stable/23011/Docker.dmg"
DOCKER_DMG_BASENAME="$(basename "$(echo "$DOCKER_DMG_DL_URL" | $SED_E -n 's/^(.*\.dmg)(\?[^?]*)?$/\1/gp')")"
DOCKER_MAC_APP_DIR_SIZE_M=1144 # to update run 'du -sm /Applications/Docker.app'
DOCKER_MAC_APP_DIR="/Applications/Docker.app"
DOCKER_MAC_APP_BIN="/Applications/Docker.app/Contents/MacOS/Docker"

CLIENT_APP_NAME="Genesis"
CLIENT_DMG_DL_URL="https://github.com/GenesisKernel/genesis-front/releases/download/v0.6.1/Genesis-0.6.1.dmg"
CLIENT_DMG_BASENAME="$(basename "$(echo "$CLIENT_DMG_DL_URL" | $SED_E -n 's/^(.*\.dmg)(\?[^?]*)?$/\1/gp')")"
CLIENT_MAC_APP_DIR_SIZE_M=226 # to update run 'du -sm /Applications/Genesis.app'
CLIENT_MAC_APP_DIR="/Applications/Genesis.app"
CLIENT_MAC_APP_BIN="/Applications/Genesis.app/Contents/MacOS/Genesis"
CLIENT_APPIMAGE_DL_URL="https://github.com/GenesisKernel/genesis-front/releases/download/v0.6.1/genesis-front-0.6.1-x86_64.AppImage"
CLIENT_APPIMAGE_BASENAME="$(basename "$(echo "$CLIENT_APPIMAGE_DL_URL" | $SED_E -n 's/^(.*\.AppImage)(\?[^?]*)?$/\1/gp')")"

BF_CONT_NAME="genesis-bf"
BF_CONT_IMAGE="str16071985/genesis-bf:$VERSION"
BF_CONT_PREV_IMAGE="str16071985/genesis-bf:$PREV_VERSION"
BF_CONT_BUILD_DIR="genesis-bf"
TRY_LOCAL_BF_CONT_NAME_ON_RUN="yes"

DB_CONT_NAME="genesis-db"
DB_CONT_IMAGE="str16071985/genesis-db:$VERSION"
DB_CONT_PREV_IMAGE="str16071985/genesis-db:$PREV_VERSION"
DB_CONT_BUILD_DIR="genesis-db"
TRY_LOCAL_DB_CONT_NAME_ON_RUN="yes"

CF_CONT_NAME="genesis-cf"
CF_CONT_IMAGE="str16071985/genesis-cf:$VERSION"
CF_CONT_PREV_IMAGE="str16071985/genesis-cf:$PREV_VERSION"
CF_CONT_BUILD_DIR="genesis-cf"
TRY_LOCAL_CF_CONT_NAME_ON_RUN="yes"

BE_CONT_NAME="genesis-be"
BE_CONT_IMAGE="str16071985/genesis-be:$VERSION"
BE_CONT_PREV_IMAGE="str16071985/genesis-be:$PREV_VERSION"
BE_CONT_BUILD_DIR="genesis-be"
TRY_LOCAL_BE_CONT_NAME_ON_RUN="yes"

FE_CONT_NAME="genesis-fe"
FE_CONT_IMAGE="str16071985/genesis-fe:$VERSION"
FE_CONT_PREV_IMAGE="str16071985/genesis-fe:$PREV_VERSION"
FE_CONT_BUILD_DIR="genesis-fe"
TRY_LOCAL_FE_CONT_NAME_ON_RUN="yes"

FORCE_COPY_IMPORT_DEMO_APPS_SCRIPTS="no"
FORCE_COPY_IMPORT_DEMO_APPS_DATA_FILES="no"
FORCE_COPY_MBS_SCRIPT="yes"

EMPTY_ENV_VARS="yes"

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
    local cmd
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

check_requirements() {
    check_curl_avail
    check_docker_avail
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

    echo "Waiting ($timeout_secs seconds) for process '$proc_name' ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_proc "$proc_name"; result=$?
        case $result in
            0|1) stop=1 ;;
            2) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

### OS #### end ####


### Disk, FS ### begin ###

get_mac_fs_type_by_path() {
    local path; path="$1"
    local dev; local mp
    eval $(df "$path"| tail -n +2 | awk '{print "dev=\""$1"\"; mp=\""$9"\";"}')
    mount | grep "$dev on $mp" | $SED_E -n 's/^[^\(]+\(([^,]+).*$/\1/p'
}

### Disk, FS #### end ####


### Host ports ### begin ###

get_host_port_proc() {
    lsof -i :$1 | grep LISTEN | awk '{print $1}' | tail -n +2
}

check_host_ports() {
    local num; num=$1;
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of clients/backends is not set" \
        && return 1
    local wps; wps=$2; [ -z "$wps" ] && wps=$WEB_PORT_SHIFT
    local cps; cps=$3; [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT
    local d_port; d_port=$4; [ -z "$d_port" ] && d_port=$DB_PORT
    local cfp; cfp=$CF_PORT # FIXME: Change to argument

    local result; result=0

    echo -n "Checking database port $d_port: "
    if [ -n "$(get_host_port_proc $d_port)" ]; then
        echo "BUSY"
        result=2
    else
        echo "FREE"
    fi

    echo -n "Checking centrifugo port $cfp: "
    if [ -n "$(get_host_port_proc $cfp)" ]; then
        echo "BUSY"
        result=5
    else
        echo "FREE"
    fi

    local w_port; local c_port; local run_cmd
    for i in $(seq 1 $num); do
        w_port=$(expr $i + $wps)
        c_port=$(expr $i + $cps)
        echo -n "Checking web port $w_port: "
        if [ -n "$(get_host_port_proc $w_port)" ]; then
            echo "BUSY"
            result=3
        else
            echo "FREE"
        fi
        echo -n "Checking client port $c_port: "
        if [ -n "$(get_host_port_proc $c_port)" ]; then
            echo "BUSY"
            result=4
        else
            echo "FREE"
        fi
    done
    return $result
}

### Host ports #### end #####


### Download/install ### begin ###

update_global_home_var() {
    local home; home="$(get_orig_user_homedir)"
    HOME="$home"
}

update_global_downloads_and_apps_dir_vars() {
    local home; home="$(get_orig_user_homedir)"
    local home_esc; home_esc="$(echo "$home" | $SED_E 's/\//\\\//g')"
    DOWNLOADS_DIR="$(echo "$DOWNLOADS_DIR" | $SED_E "s/\\\$HOME/$home_esc/g")"
    APPS_DIR="$(echo "$APPS_DIR" | $SED_E "s/\\\$HOME/$home_esc/g")"
}

create_downloads_dir() {
    [ -d "$DOWNLOADS_DIR" ] && return 0
    run_as_orig_user "mkdir -p '$DOWNLOADS_DIR'"
}

create_apps_dir() {
    [ -d "$APPS_DIR" ] && return 0
    run_as_orig_user "mkdir -p '$APPS_DIR'"
}

get_app_dir_size_m() {
    [  -d "$1" ] &&  du -sm "$1" | awk '{print $1}' || echo 0
}

download_and_check_dmg() {
    check_curl_avail
    local dmg_url; dmg_url="$1"
    local dmg_basename; dmg_basename="$2"
    local result
    (
        update_global_downloads_and_apps_dir_vars

        local dmg_path; dmg_path="$DOWNLOADS_DIR/$dmg_basename"
        echo "1 dmg_path: $dmg_path"
        [ -f "$dmg_path" ] \
            && mv "$dmg_path" "$dmg_path.bak.$(date "+%Y%m%d%H%M%S")"
        create_downloads_dir \
            && echo "Downloading $app_name ..." \
            && curl -L -o "$dmg_path" "$dmg_url"
    ); result=$?
    case $result in
        77)
            echo
            echo "To fix this error you need to update CA certificate file."
            echo "Please read ISSUES.md 'curl: (77) SSL: can't load CA certificate file' section"
            echo "See also https://curl.haxx.se/docs/sslcerts.html for details."
            echo "See also https://curl.haxx.se/docs/caextract.html for download URLs."
            echo
            return $result
            ;;
        0) echo "$dmg_path" ;;
        *) return $result ;;
    esac
}

download_and_install_dmg() {
    check_curl_avail
    local app_bin; app_bin="$1"
    local app_dir; app_dir="$2"
    local dmg_url; dmg_url="$3"
    local dmg_basename; dmg_basename="$4"
    local app_name; app_name="$5"
    local exp_size_m; exp_size_m=$6

    local timeout_secs; timeout_secs="380"

    local result; result=0

    if [ ! -f "$app_bin" ]; then
        (
            update_global_downloads_and_apps_dir_vars

            local dmg_path; dmg_path="$DOWNLOADS_DIR/$dmg_basename"
            if [ ! -f "$dmg_path" ]; then
                create_downloads_dir \
                    && echo "Downloading $app_name ..." \
                    && curl -L -o "$dmg_path" "$dmg_url" && open "$dmg_path"
            else
                open "$dmg_path"
            fi
        ); result=$?
        case $result in
            77)
                echo
                echo "To fix this error you need to update CA certificate file."
                echo "Please read ISSUES.md 'curl: (77) SSL: can't load CA certificate file' section"
                echo "See also https://curl.haxx.se/docs/sslcerts.html for details."
                echo "See also https://curl.haxx.se/docs/caextract.html for download URLs."
                echo
                return $result
                ;;
            0) : ;;
            *) return $result ;;
        esac
        local end_time; end_time=$(( $(date +%s) + timeout_secs ))
        local stop; stop=0
        local cnt; cnt=0
        while [ $stop -eq 0 ]; do
            echo "Please move $app_name to Applications"
            [ -f "$app_bin" ] && stop=1
            [ $(date +%s) -lt $end_time ] || stop=2
            [ $cnt -ge 0 ] && sleep 1
        done
        case $stop in 
            2) echo "Waiting time for $app_name is out" && return 11
        esac

        echo "$app_name is copying to Applications. Please wait (timeout: $timeout_secs seconds) ..."
        end_time=$(( $(date +%s) + timeout_secs ))
        stop=0
        while [ $stop -eq 0 ]; do
            [ $(get_app_dir_size_m "$app_dir") -ge $exp_size_m ] \
                && stop=1
            read -n 1 -s -t 1 answ
            if [ $? -eq 0 ] && [ "${answ%\\n}" = "s" ]; then
                echo "You did input: '$answ'"
                stop=2
            fi
            [ $(date +%s) -lt $end_time ] || stop=3
            echo "Wait until the copying is complete or press 's' key to skip this waiting"
        done
        case $stop in
            1)
                echo "$app_name installed"
                result=0
                ;;
            2)
                echo "$app_name probably installed (you skipped waiting)"
                result=21
                ;;
            3)
                echo "$app_name probably installed (there was a timeout)"
                result=22
                ;;
        esac
    fi
    return $result
}

### Download/install #### end ####


### Docker ### begin ###

install_mac_docker_directly() {
    download_and_install_dmg "$DOCKER_MAC_APP_BIN" "$DOCKER_MAC_APP_DIR" "$DOCKER_DMG_DL_URL" "$DOCKER_DMG_BASENAME" "$DOCKER_APP_NAME" $DOCKER_MAC_APP_DIR_SIZE_M
}

install_linux_docker() {
    [ -n "$(command -v docker)" ] && return 0

    local dist; dist="$1"

    case "$dist" in
        [Ff][Ee][Dd][Oo][Rr][Aa])
            dnf -y install dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            dnf -y install docker-ce
            systemctl start docker && systemctl enable docker
            ;;

        [Cc][Ee][Nn][Tt][Oo][Ss])
            ;;

        [Dd][Ee][Bb][Ii][Aa][Nn])
            apt-get update -y --fix-missing
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg2 \
                software-properties-common
            curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -
            apt-key fingerprint 0EBFCD88
            add-apt-repository \
                "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
                $(lsb_release -cs) \
                stable"
            apt-get update -y
            apt-get install docker-ce -y
            systemctl start docker &&  systemctl enable docker
            ;;

        [Uu][Bb][Uu][Nn][Tt][Uu])
            apt-get update -y --fix-missing
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
            apt-key fingerprint 0EBFCD88
            add-apt-repository \
                "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) \
                stable"
            apt-get update -y
            apt-get install docker-ce -y
            systemctl start docker &&  systemctl enable docker
            ;;

        [Mm][Ii][Nn][Tt])
            apt-get update -y --fix-missing
            apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 \
            --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
            apt-add-repository \
                'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
            apt-get update -y
            apt-get install docker.io -y
            systemctl start docker &&  systemctl enable docker
            ;;
    esac
}

install_docker() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        mac)
            install_mac_docker_directly
            ;;

        linux)
            install_linux_docker
            ;;

        *)
            echo "Sorry, but $os_type is not supported yet"
            return 10
            ;;
    esac
}

uninstall_mac_docker() {
    if [ "${USER}" != "root" ]; then
        echo "Please run this command with sudo or as root"
    	return 2
    fi

    if [ -e "$DOCKER_MAC_APP_BIN" ]; then
        $DOCKER_MAC_APP_BIN --uninstall
    fi
    
    if [ -n "$(command -v  docker-machine)" ]; then
        while true; do
            read -p "Remove all $DOCKER_APP_NAME Machine VMs? (Y/N): " yn
            case $yn in
                [Yy]* ) docker-machine rm -f $(docker-machine ls -q); break ;;
                [Nn]* ) break ;;
                * ) echo "Please answer yes or no."; exit 1;;
            esac
        done
    fi
    
    echo "Removing $DOCKER_APP_NAME from Applications..."
    [ -e "$DOCKER_MAC_APP_DIR" ] \
        && rm -rf "$DOCKER_MAC_APP_DIR"
    
    echo "Removing $DOCKER_APP_NAME binaries..."
    [ -e /usr/local/bin/docker ] \
        && rm -f /usr/local/bin/docker
    [ -e /usr/local/bin/docker-machine ] \
        && rm -f /usr/local/bin/docker-machine
    find /usr/local/bin -name 'docker-machine-driver*' -delete
    [ -e /usr/local/bin/docker-compose ] \
        && rm -f /usr/local/bin/docker-compose
    
    echo "Removing boot2docker.iso"
    [ -e /usr/local/share/boot2docker ] \
        && rm -rf /usr/local/share/boot2docker
    
    echo "Forget packages"
    pkgutil --forget io.docker.pkg.docker
    pkgutil --forget io.docker.pkg.dockercompose
    pkgutil --forget io.docker.pkg.dockermachine
    pkgutil --forget io.boot2dockeriso.pkg.boot2dockeriso
   
    local pids; pids="$(pgrep docker)" 
    [ -n "$pids" ] && echo "Terminating docker processes ..." \
        && kill $pids

    echo "$DOCKER_APP_NAME completely removed"
}

uninstall_docker() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        mac)
            uninstall_mac_docker
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            return 10
            ;;
    esac
}

check_docker_ready_status() {
    [ -z "$(command -v docker)" ] && return 100
    docker ps -a 1>&2>/dev/null
}

wait_docker_ready_status() {
    local timeout_secs; [ -z "$1" ] && timeout_secs=15 || timeout_secs=$1
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for docker daemon ready status ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_docker_ready_status; result=$?
        case $result in
            0) stop=1; echo "ok" ;;
            *) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

start_mac_docker() {
    install_mac_docker_directly
    [ $? -ne 0 ] \
        && echo "Can't download docker" && return 1
    open -n "$DOCKER_MAC_APP_DIR"
    wait_proc docker 120
    [ $? -ne 0 ] \
        && echo "No docker process. Please reinstall docker." \
        && echo "You can use $(basename "$0") uninstall-docker to uninstall docker" \
        && return 10
    wait_docker_ready_status 120
    [ $? -ne 0 ] \
        && echo "Docker daemon isn't ready. Please reinstall docker." \
        && echo "You can use $(basename "$0") uninstall-docker to uninstall docker" \
        && return 11
    echo "Docker ready"
    return 0
}


start_linux_docker() {
    install_linux_docker "$(get_linux_dist)"
    [ -n "$(command -v docker)" ] && return 0
}

start_docker() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux)
            start_linux_docker
            ;;
        mac)
            start_mac_docker
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            exit 30
            ;;
    esac
}

check_docker_avail() {
    [ -n "$(command -v docker)" ] && return 0
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux)
            start_linux_docker
            ;;
        mac)
            start_mac_docker
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            exit 30
            ;;
    esac
}

### Docker #### end ####


### Client ### begin ###

check_curl_avail() {
    [ -n "$(command -v curl)" ] && return 0
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux|mac)
            echo "Please install curl first"
            exit 31
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            exit 30
            ;;
    esac
}

install_mac_client_directly() {
    download_and_install_dmg "$CLIENT_MAC_APP_BIN" "$CLIENT_MAC_APP_DIR" "$CLIENT_DMG_DL_URL" "$CLIENT_DMG_BASENAME" "$CLIENT_APP_NAME" $CLIENT_MAC_APP_DIR_SIZE_M
}

uninstall_mac_client() {
    if [ "${USER}" != "root" ]; then
        echo "Please run this command with sudo or as root"
    	return 2
    fi

    if [ -e "$CLIENT_MAC_APP_DIR" ]; then
        echo "Removing $CLIENT_APP_NAME from Applications..."
        rm -rf "$CLIENT_MAC_APP_DIR"
    fi

    echo "$CLIENT_APP_NAME completely removed"
}

uninstall_client() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        mac)
            uninstall_mac_client
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            return 10
            ;;
    esac
}

install_linux_client_directly() {
    check_curl_avail
    (
        update_global_downloads_and_apps_dir_vars
        local app_basename; app_basename="$CLIENT_APPIMAGE_BASENAME"
        local app_dl_path; app_dl_path="$DOWNLOADS_DIR/$app_basename"
        local app_inst_path; app_inst_path="$APPS_DIR/$app_basename"

        if [ ! -f "$app_inst_path" ]; then
            if [ ! -f "$app_dl_path" ]; then
                create_downloads_dir \
                    && echo "Downloading Client ..." \
                    && run_as_orig_user "curl -L -o '$app_dl_path' '$CLIENT_APPIMAGE_DL_URL'"
            fi
            create_apps_dir \
                && mv "$app_dl_path" "$app_inst_path" \
                && chmod +x "$app_inst_path"
        fi
    )
}


start_mac_clients() {
    local num; num=$1;
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of clients is not set" \
        && return 100
    local wps; wps=$2; [ -z "$wps" ] && wps=$WEB_PORT_SHIFT
    local cps; cps=$3; [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT
    #local cfp; cfp=$4; [ -z "$cfp" ] && cfp=$CF_PORT
    local cfp; cfp=$CF_PORT # FIXME: change to parameter

    install_mac_client_directly
    case $? in
        21|22|0) : ;;
        *) echo "Can't download/install client" && return 101 ;;
    esac

    local w_port; local c_port; local run_cmd
    local offset_x; offset_x=0; local offset_y; offset_y=0
    for i in $(seq 1 $num); do
        w_port=$(expr $i + $wps)
        c_port=$(expr $i + $cps)
        echo "Starting client $i (web port: $w_port; client port: $c_port) ..."
        run_cmd="open -n $CLIENT_MAC_APP_DIR --args API_URL=http://127.0.0.1:$c_port/api/v2 PRIVATE_KEY=http://127.0.0.1:$w_port/keys/PrivateKey SOCKET_URL=http://127.0.0.1:$cfp --nosave --offsetX $offset_x --offsetY $offset_y"
        eval "$run_cmd"
        offset_x=$(expr $offset_x + 50) 
        offset_y=$(expr $offset_y + 50) 
    done
}

start_linux_clients() {
    local num; num=$1;
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of clients is not set" \
        && return 200
    local wps; wps=$2; [ -z "$wps" ] && wps=$WEB_PORT_SHIFT
    local cps; cps=$3; [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT
    #local cfp; cfp=$4; [ -z "$cfp" ] && cfp=$CF_PORT
    local cfp; cfp=$CF_PORT # FIXME: change to parameter

    install_linux_client_directly

    (
        update_global_downloads_and_apps_dir_vars

        local app_basename; app_basename="$CLIENT_APPIMAGE_BASENAME"
        local app_inst_path; app_inst_path="$APPS_DIR/$app_basename"

        local w_port; local c_port; local run_cmd
        for i in $(seq 1 $num); do
            w_port=$(expr $i + $wps)
            c_port=$(expr $i + $cps)
            echo "Starting client $i (web port: $w_port; client port: $c_port) ..."
            run_cmd="$app_inst_path API_URL=http://127.0.0.1:$c_port/api/v2 PRIVATE_KEY=http://127.0.0.1:$w_port/keys/PrivateKey SOCKET_URL=http://127.0.0.1:$cfp --nosave &"
            run_as_orig_user "$run_cmd"
        done
    )
}

start_clients() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux)
            start_linux_clients $@
            ;;
        mac)
            start_mac_clients $@
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            return 10
            ;;
    esac
}

stop_mac_clients() {
    local max_tries; max_tries=20
    local cnt; cnt=1; local stop; stop=0; local pids
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        pids=$(pgrep -f "Genesis API_URL")
        [ -n "$pids" ] && pids="$(echo "$pids" | tr '\n' ' ')" \
            && echo "Stopping clients ..." && kill $pids \
            || stop=1
        [ $cnt -gt $max_tries ] && echo "Can't stop clients ..." && return 1
        cnt=$(expr $cnt + 1)
    done
}

stop_linux_clients() {
    local max_tries; max_tries=20
    local cnt; cnt=1; local stop; stop=0; local pids
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        pids=$(pgrep -f "genesis API_URL")
        [ -n "$pids" ] && pids="$(echo "$pids" | tr '\n' ' ')" \
            && echo "Stopping clients ..." && kill $pids \
            || stop=1
        [ $cnt -gt $max_tries ] && echo "Can't stop clients ..." && return 1
        cnt=$(expr $cnt + 1)
    done
}

stop_clients() {
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux)
            stop_linux_clients
            ;;
        mac)
            stop_mac_clients
            ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            return 10
            ;;
    esac
}

### Client #### end ####


### Common containers ### begin ###

get_cont_id() {
    docker ps -a -f name="$1" --format '{{.ID}}'
}

get_running_cont_id() {
    docker ps -f name="$1" -f status=running --format '{{.ID}}'
}

check_cont() {
    [ -z "$(get_cont_id $1)" ] \
        && echo "Container with name '$1' doesn't exist" && return 1
    id="$(get_running_cont_id $1)"
    [ -z "$id" ] \
        && echo "Container with name '$1' isn't running" && return 2
    echo "$id"
}

get_cont_status() {
    local result; result=0
    local id; id=$(check_cont "$1"); result=$?
    case $result in
        1)  
            echo "absent"
            ;;
        2)
            echo "not-running"
            ;;
        0)
            echo "running"
            ;;
        *)
            echo "unknown"
            ;;
    esac
    return $result
}

cont_exec() {
    local name; name="$1"
    local id; id=$(check_cont "$name"); [ $? -ne 0 ] && return 1
    shift 1
    local run_cmd; run_cmd="docker exec -ti $id $@"
    eval "$run_cmd"
}

prep_cont_for_inspect() {
    #cont_exec $1 "bash -c \"apt update --fix-missing; apt install -y tmux telnet net-tools vim nano links procps\""
    cont_exec $1 "bash -c 'apt update --fix-missing; apt install -y tmux telnet net-tools vim nano links screen procps'"
}

prep_cont_for_inspect_centos7() {
    cont_exec $1 "bash -c 'dnf install -y tmux telnet net-tools vim nano links'"
}

cont_bash() {
    cont_exec "$1" bash
}

remove_cont() {
    check_cont $1 > /dev/null
    [ $? -ne 1 ] && echo -n "Stopping/removing " && docker rm -f $1 
}

check_cont_proc() {
    [ -z "$1" ] && echo "Container name isn't set" && return 1
    [ -z "$2" ] && echo "Process name isn't set" && return 2
    check_cont "$1" > /dev/null; [ $? -ne 0 ] \
        && echo "Container '$1' isn't available " && return 3
    [ -z "$(docker exec -t "$1" pgrep "$2")" ] \
        && echo "No process '$2' @ container '$1'" && return 4
    return 0
}

wait_cont_proc() {
    local cont_name; cont_name="$1"
    local proc_name; proc_name="$2"
    local timeout_secs; [ -z "$3" ] && timeout_secs=15 || timeout_secs="$3"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for process '$proc_name' @ container '$cont_name' ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_cont_proc "$cont_name" "$proc_name"; result=$?
        case $result in
            0|1|2) stop=1 ;;
            3|4) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

gen_docker_p_args() {
    local num; num=$1; ([ -z "$num" ] || [ $num -eq 0 ]) && return 1
    local hsh; hsh=$2; [ -z "$hsh" ] && hsh=0
    local gsh; gsh=$3; [ -z "$gsh" ] && gsh=$hsh

    local s; s=""
    for i in $(seq 1 $num); do
        [ -n "$s" ] && s="$s "
        s="${s}-p $(expr $i + $hsh):$(expr $i + $gsh)"
    done
    echo "$s"
}

### Common containers #### end ####


### DB container ### begin ###

start_db_cont() {
    local dbp; dbp=$1
    [ -z "$dbp" ] && dbp=$DB_PORT
    check_cont $DB_CONT_NAME > /dev/null
    case $? in
        1)  
            local image_name
            if [ "$TRY_LOCAL_DB_CONT_NAME_ON_RUN" = "yes" ]; then
                local loc; loc=$(docker images --format "{{.Repository}}" -f "reference=$DB_CONT_NAME")
                [ -n "$loc" ] && image_name="$DB_CONT_NAME" \
                    || image_name="$DB_CONT_IMAGE"
            else
                image_name="$DB_CONT_IMAGE"
            fi
            echo "Creating a new database container from image '$image_name' ..."
            docker run -d --restart always --name $DB_CONT_NAME -p $dbp:$CONT_DB_PORT -t $image_name
            ;;
        2)
            echo "Starting database container (host port: $dbp) ..."
            docker start $DB_CONT_NAME &
            ;;
        0)
            echo "Database container is already running"
            ;;
        *)
            echo "Unknown database container status"
            ;;
    esac
}

### DB container #### end ####


### CF container ### begin ###

start_cf_cont() {
    local cfp; cfp=$1
    [ -z "$cfp" ] && cfp=$CF_PORT
    check_cont $CF_CONT_NAME > /dev/null
    case $? in
        1)  
            local image_name
            if [ "$TRY_LOCAL_CF_CONT_NAME_ON_RUN" = "yes" ]; then
                local loc; loc=$(docker images --format "{{.Repository}}" -f "reference=$CF_CONT_NAME")
                [ -n "$loc" ] && image_name="$CF_CONT_NAME" \
                    || image_name="$CF_CONT_IMAGE"
            else
                image_name="$CF_CONT_IMAGE"
            fi
            echo "Creating a new centrifugo container from image '$image_name' ..."
            docker run -d --restart always --name $CF_CONT_NAME -p $cfp:$CONT_CF_PORT -t $image_name
            ;;
        2)
            echo "Starting centrifugo container (host port: $cfp) ..."
            docker start $CF_CONT_NAME &
            ;;
        0)
            echo "Centrifugo container is already running"
            ;;
        *)
            echo "Unknown centrifugo container status"
            ;;
    esac
}

### CF container #### end ####


### BF container ### begin ###

start_bf_cont() {
    local num; ([ -z "$1" ] || [ $1 -lt 1 ]) \
        && echo "The number of backends isn't set" && return 1 || num=$1
    local wps; [ -z "$2" ] && wps=$WEB_PORT_SHIFT || wps=$2
    local cps; [ -z "$3" ] && cps=$CLIENT_PORT_SHIFT || cps=$3

    check_cont $BF_CONT_NAME > /dev/null
    case $? in
        1)  

            local w_ports;
            w_ports=$(gen_docker_p_args $num $wps $CONT_WEB_PORT_SHIFT)
            local c_ports;
            c_ports=$(gen_docker_p_args $num $cps $CONT_CLIENT_PORT_SHIFT)

            local image_name
            if [ "$TRY_LOCAL_BF_CONT_NAME_ON_RUN" = "yes" ]; then
                local loc; loc=$(docker images --format "{{.Repository}}" -f "reference=$BF_CONT_NAME")
                [ -n "$loc" ] && image_name="$BF_CONT_NAME" \
                    || image_name="$BF_CONT_IMAGE"
            else
                image_name="$BF_CONT_IMAGE"
            fi
            echo "Creating a new backend/frontend container from image '$image_name' ..."
            #docker run -d --restart always --name $BF_CONT_NAME $w_ports $c_ports -v apla:/s --link $DB_CONT_NAME:$DB_CONT_NAME --link $CF_CONT_NAME:$CF_CONT_NAME -t $image_name
            docker run -d --restart always --name $BF_CONT_NAME $w_ports $c_ports --link $DB_CONT_NAME:$DB_CONT_NAME --link $CF_CONT_NAME:$CF_CONT_NAME -t $image_name
            ;;
        2)
            echo "Starting backend/frontend container ..."
            docker start $BF_CONT_NAME &
            ;;
        0)
            echo "Backend/frontend container is already running"
            ;;
        *)
            echo "Unknown backend/frontend container status"
            ;;
    esac
}

### BF container #### end ####


### Database ### begin ###

check_db_exists() {
    local db_name; db_name="$1"; [ -z "$db_name" ] \
        && echo "DB name isn't set" && return 1
    check_cont $DB_CONT_NAME > /dev/null; [ $? -ne 0 ] \
        && echo "DB container isn't available" && return 2
    local db; db=$(docker exec -ti $DB_CONT_NAME bash -c "sudo -u postgres psql -lqt" | $SED_E -n "s/^[^e]*($db_name)[^|]+.*$/\1/gp")
    [ -z "$db" ] && echo "DB '$db_name' doesn't exist" && return 3
    return 0
}

wait_db_exists() {
    local db_name; db_name="$1"
    local timeout_secs; [ -z "$2" ] && timeout_secs=15 || timeout_secs="$2"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for database '$db_name' existence ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_db_exists "$1"; result=$?
        case $result in
            1|0) stop=1 ;;
            2|3) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    [ $result -eq 0 ] && echo "ok"
    return $result
}

### Update ### 20180405 ### 08fad ### begin ###

check_dbs() {
    local num; num=$1
    echo "Checking databases for $num backends ..."
    local total_result; total_result=0; local result
    local db_name
    for i in $(seq 1 $num); do
        db_name="$GENESIS_DB_NAME_PREFIX$i"
        echo -n "  checking database for backend $i: "
        check_db_exists "$db_name"; result=$?
        [ $result -ne 0 ] && total_result=$result || echo "ok"
    done
    return $total_result
}

wait_dbs() {
    local num; num=$1
    local timeout_secs; [ -z "$2" ] && timeout_secs=15 || timeout_secs="$2"
    echo "Waiting ($timeout_secs seconds for each) databases for $num backends ..."
    local total_result; total_result=0; local result db_name
    for i in $(seq 1 $num); do
        db_name="$GENESIS_DB_NAME_PREFIX$i"
        echo "  checking database for backend $i: "
        wait_db_exists "$db_name" $timeout_secs; result=$?
        [ $result -ne 0 ] && total_result=$result || echo "ok"
    done
    return $total_result
}

create_dbs() {
    local num; num=$1
    local timeout_secs; timeout_secs=$2
    local max_tries; [ -z "$3" ] && max_tries=5 || max_tries=$3

    echo "Creating/checking databases for $num backends ..."
    local total_result; total_result=0; local result db_name
    local cnt; local stop
    for i in $(seq 1 $num); do
        db_name="$GENESIS_DB_NAME_PREFIX$i"
        cnt=1; stop=0
        while [ $stop -eq 0 ]; do
            if [ $cnt -gt 1 ]; then
                wait_db_exists "$db_name" $timeout_secs; result=$?
            else
                echo "Quick checking database '$db_name' existence ..."
                check_db_exists "$db_name"; result=$?
            fi
            case $result in
                0)
                    [ $cnt -gt 1 ] && echo "Database '$db_name' exists" \
                        || echo "Database '$db_name' already exists"
                    stop=1
                    ;;
                3)
                    echo "Creating '$db_name' database ..."
                    docker exec -ti $DB_CONT_NAME bash /db.sh create postgres "$db_name"
                    ;;
                *) total_result=$result ;;
            esac
            [ $cnt -ge $max_tries ] && total_result=20 && stop=1
            cnt=$(expr $cnt + 1)
        done
    done
}


run_db_shell() {
    local db_name
    [ -z "$1" ] && echo "Backend's number isn't set" && return 1 \
        || db_name="$GENESIS_DB_NAME_PREFIX$1"
    check_db_exists "$db_name" || return 3
    docker exec -ti $DB_CONT_NAME bash -c \
        "sudo -u postgres psql -U postgres -d $db_name"
}

do_db_query() {
    local out_mode; 
    [ -z "$1" ] && echo "Output mode isn't set" && return 1 \
        || out_mode="$1"
    local db_name
    [ -z "$2" ] && echo "Backend's number isn't set" && return 1 \
        || db_name="$GENESIS_DB_NAME_PREFIX$2"
    shift 2
    [ -z "$1" ] \
        && echo "Query string isn't set" && return 2
    local query; query="$@";
    check_db_exists "$db_name" || return 3
    local query_esc; query_esc="$(echo "$query" | $SED_E "s#\\\\[*]#*#g")"
    case $out_mode in
        t-md5) docker exec -ti $DB_CONT_NAME bash -c \
                "sudo -u postgres psql -U postgres -d $db_name -t -c '$query_esc' | md5sum | sed -E -n 's/^([0-9a-zA-Z]{32}).*$/\1/p'"
            ;;
        t) docker exec -ti $DB_CONT_NAME bash -c \
            "sudo -u postgres psql -U postgres -d $db_name -t -c '$query_esc'"
            ;;
        comn|*) docker exec -ti $DB_CONT_NAME bash -c \
            "sudo -u postgres psql -U postgres -d $db_name -c '$query_esc'"
            ;;
    esac
}

block_chain_count() {
    local num; num="$1"; local query db_name
    for i in $(seq 1 $num); do
        db_name="$GENESIS_DB_NAME_PREFIX$i"
        query='SELECT COUNT(*) FROM block_chain'
        echo -n "$db_name: $query: "
        do_db_query comn "$i" "$query" | tail -n +4 | head -n +1 | $SED_E 's/^ +//'
    done
}

get_first_blocks() {
    local num
    [ -z "$1" ] && echo "The number of backends isn't set" && return 1 || num=$1
    local query; local out; local prev; local res; res=0
    for i in $(seq 1 $num); do
        query='SELECT key_id FROM block_chain WHERE id=1'
        echo -n "backend #$i db: $query: "
        do_db_query t "$i" "$query" | $SED_E -e 's/^[^0-9]+//' -e '/^\s*$/d'
    done
}

### Update ### 20180405 ### 08fad #### end ####

cmp_first_blocks() {
    local num
    [ -z "$1" ] && echo "the number of backends isn't set" && return 1 || num=$1
    [ $num -eq 1 ] && echo "The backend is single" && return 0
    local query; local out; local prev; local res; result=0
    for i in $(seq 1 $num); do
        prev="$out"
        query='SELECT key_id FROM block_chain WHERE id=1'
        out="$(do_db_query t "$i" "$query" | $SED_E -e 's/^[^0-9]+//' -e '/^\s*$/d')"
        [ $i -gt 1 ] && [ "$prev" != "$out" ] && result=1
    done
    [ $result -ne 0 ] && echo "first blocks differ" && return 2
    echo "first blocks are the same: $out" 
}

cmp_keys() {
    local num
    [ -z "$1" ] && echo "Backend's number isn't set" && return 1 || num=$1
    [ $num -eq 1 ] && echo "The backend is single" && return 0
    local prev; local result; result=0
    for i in $(seq 1 $num); do
        prev="$out"
        out="$(do_db_query t-md5 $i "select id, pub from \"1_keys\" order by id;")"
        [ $i -gt 1 ] && [ "$prev" != "$out" ] && result=1
    done
    [ $result -ne 0 ] && echo "keys differ" && return 2
    echo "keys are the same" 
}

wait_keys_sync() {
    local num;
    [ -z "$1" ] && echo "Backend's number isn't set" && return 1 || num=$1
    local timeout_secs; [ -z "$2" ] && timeout_secs=25 || timeout_secs="$2"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))
    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    local out
    echo "Waiting ($timeout_secs seconds) for keys synchronization to complete ..."
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        cmp_keys "$1"; result=$?
        case $result in
            1|0) stop=1 ;;
            2) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    [ $result -eq 0 ] && echo "OK: keys are synchronized"
    return $result
}

### Database #### end ####


### Backends services ### begin ###

check_cont_http() {
    [ -z "$1" ] && echo "Container name isn't set" && return 1
    [ -z "$2" ] && echo "URL isn't set" && return 2
    check_cont "$1" > /dev/null; [ $? -ne 0 ] \
        && echo "Container '$1' isn't available " && return 3
    local result
    local resp; resp="$(docker exec -t "$1" curl $2 --stderr -)"; result=$?
    [ -n "$(echo "$resp" | grep "Could not resolve host")" ] \
        && echo "Could not resolve host" && return 4
    [ $result -ne 0 ] && echo "HTTP Request Error: $resp" && return 5
    echo "ok"
    return 0
}

wait_cont_http() {
    local cont_name; cont_name="$1"
    local url; url="$2"
    local timeout_secs; [ -z "$3" ] && timeout_secs=15 || timeout_secs="$3"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for HTTP response to URL '$url' @ container '$cont_name' ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_cont_http "$cont_name" "$url"; result=$?
        case $result in
            0|1|2|4) stop=1 ;;
            3|5) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

check_http_code() {
    [ -z "$1" ] && echo "URL isn't set" && return 1
    [ -z "$2" ] && echo "List of OK codes isn't set" \
        && return 2
    local resp; resp="$(curl -sv "$1" --stderr -)"
    [ -n "$(echo "$resp" | grep "Could not resolve host")" ] \
        && echo "Could not resolve host" && return 3
    [ -n "$(echo "$resp" | grep "failed: Connection refused")" ] \
        && echo "Connection refused" && return 4
    local code; code="$(echo "$resp" | $SED_E -n 's/^< HTTP[^ ]* ([0-9]+)[^0-9]+.*$/\1/gp')"
    local c; local result; result=1; IFS=','
    for c in $2; do
        [ "$c" = "$code" ] && result=0 && break
    done
    unset IFS;
    [ $result -ne 0 ] && echo "Bad HTTP Response code '$code' (OK-codes: '$2')" && return 5
    echo "ok"
    return 0
}

wait_http_code() {
    local url; url="$1"
    local codes; codes="$2"
    local timeout_secs; [ -z "$3" ] && timeout_secs=15 || timeout_secs="$3"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for HTTP response with one of OK-code ($codes) to URL '$url' request ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_http_code "$url" "$codes"; result=$?
        case $result in
            0|1|2|3) stop=1 ;;
            4|5) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

check_cont_http_code() {
    [ -z "$1" ] && echo "Container name isn't set" && return 1
    [ -z "$2" ] && echo "URL isn't set" && return 2
    [ -z "$3" ] && echo "List of OK codes isn't set" \
        && return 3
    check_cont "$1" > /dev/null; [ $? -ne 0 ] \
        && echo "Container '$1' isn't available " && return 4
    local resp; resp="$(docker exec -t "$1" curl -sv "$2" --stderr -)"
    [ -n "$(echo "$resp" | grep "Could not resolve host")" ] \
        && echo "Could not resolve host" && return 5
    [ -n "$(echo "$resp" | grep "failed: Connection refused")" ] \
        && echo "HTTP Connection refused" && return 6
    local code; code="$(echo "$resp" | $SED_E -n 's/^< HTTP[^ ]* ([0-9]+)[^0-9]+.*$/\1/gp')"
    local c; local result; result=1; IFS=','
    for c in $3; do
        [ "$c" = "$code" ] && result=0 && break
    done
    unset IFS;
    [ $result -ne 0 ] && echo "Bad HTTP Response code '$code' (OK-codes: '$3')" && return 7
    echo "ok"
    return 0
}

wait_cont_http_code() {
    local cont_name; cont_name="$1"
    local url; url="$2"
    local codes; codes="$3"
    local timeout_secs; [ -z "$4" ] && timeout_secs=15 || timeout_secs="$4"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for HTTP response with one of OK-code ($codes) to URL '$url' request @ container '$cont_name' ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_cont_http_code "$cont_name" "$url" "$codes"; result=$?
        case $result in
            0|1|2|3|5) stop=1 ;;
            4|6|7) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

get_http_len() {
    [ -z "$1" ] && echo "URL isn't set" && return 1
    [ -z "$2" ] && echo "List of OK codes isn't set" \
        && return 2
    [ -z "$3" ] && echo "Content-Length minimal size (bytes) isn't set" \
        && return 3
    local resp; resp="$(curl -sv "$1" --stderr -)"
    [ -n "$(echo "$resp" | grep "Could not resolve host")" ] \
        && echo "Could not resolve host" && return 4
    [ -n "$(echo "$resp" | grep "failed: Connection refused")" ] \
        && echo "HTTP Connection refused" && return 5
    local code; code="$(echo "$resp" | $SED_E -n 's/^< HTTP[^ ]* ([0-9]+)[^0-9]+.*$/\1/gp')"
    local c; local result; result=1; IFS=','
    for c in $2; do
        [ "$c" = "$code" ] && result=0 && break
    done
    unset IFS;
    [ $result -ne 0 ] && echo "Bad HTTP Response code '$code' (OK-codes: '$3')" && return 6
    local len; len="$(echo "$resp" | $SED_E -n 's/^[^C]*Content-Length: ([0-9]+)[^0-9]*.*$/\1/gp')"
    [ -z "$len" ] && echo "No Content-Length in HTTP response" && return 7
    [ $len -lt $3 ] && echo "HTTP Content-Length '$len' is lesser than minimal '$3'" && return 8
    local data; data="$(echo "$resp" | $SED_E -n 's/^([^\*<>]+).*$/\1/pg' | grep -v '{ \[')"
    echo "$data"
}

check_http_len() {
    local result; local out; out="$(get_http_len $@)"; result=$?
    [ $result -ne 0 ] && ([ -n "$out" ] && echo "$out" || :) && return $result
    echo "ok"
}

wait_http_len() {
    local url; url="$1"
    local codes; codes="$2"
    local min_len; min_len="$3"
    local timeout_secs; [ -z "$4" ] && timeout_secs=15 || timeout_secs="$4"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for HTTP response with one of OK-code ($codes) and Content-Length more or equal to '$min_len' bytes to URL '$url' request @ container '$cont_name' ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_http_code_len "$url" "$codes" "$min_len"; result=$?
        case $result in
            0|1|2|3|4) stop=1 ;;
            5|6|7|8) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

# URL template: 'http://127.0.0.1:PORT/keys/PrivateKey'
get_http_priv_key() {
    [ -z "$1" ] && echo "URL template isn't set" && return 1
    [ -z "$2" ] && echo "The index number of backend isn't set" && return 2
    [ -z "$3" ] && echo "List of OK codes isn't set" \
        && return 3
    [ -z "$4" ] && echo "Content-Length minimal size (bytes) isn't set" \
        && return 4
    [ -z "$5" ] && wps=$WEB_PORT_SHIFT || wps=$5
    local port; port=$(expr $wps + $2)
    local url; url="$(echo "$1" | $SED_E "s/:PORT/:$port/g")"
    local resp; resp="$(curl -vs "$url" --stderr -)"
    [ -n "$(echo "$resp" | grep "Could not resolve host")" ] \
        && echo "Could not resolve host" && return 5
    [ -n "$(echo "$resp" | grep "failed: Connection refused")" ] \
        && echo "HTTP Connection refused" && return 6
    local code; code="$(echo "$resp" | $SED_E -n 's/^< HTTP[^ ]* ([0-9]+)[^0-9]+.*$/\1/gp')"
    local c; local result; result=1; IFS=','
    for c in $3; do
        [ "$c" = "$code" ] && result=0 && break
    done
    unset IFS;
    [ $result -ne 0 ] && echo "Bad HTTP Response code '$code' (OK-codes: '$3')" && return 7
    local len; len="$(echo "$resp" | $SED_E -n 's/^[^C]*Content-Length: ([0-9]+)[^0-9]*.*$/\1/gp')"
    [ -z "$len" ] && echo "No Content-Length in HTTP response" && return 8
    [ $len -lt $4 ] && echo "HTTP Content-Length '$len' is lesser than minimal '$3'" && return 9
    local data; data="$(echo "$resp" | $SED_E -n 's/^([^\*<>\{]+)\* .*$/\1/pg')"
    local chck; chck="$(echo -n "$data" | $SED_E -n 's/^([a-zA-Z0-9]{64})$/\1/p')"
    [ -z "$chck" ] \
        && echo "Data '$data' doesn't match to REGEX /^([a-zA-Z0-9]{64})$/" \
        && return 10 
    echo "$data"
}

get_priv_key() {
    [ -z "$1" ] && echo "The index number of a backend isn't set" && return 1
    local idx; idx="$1"
    local num; local wps; local cps; local dbp; local cfp
    read_install_params_to_vars || return 2
    [ $idx -gt $num ] && echo "The total number of backends is $num" && return 3
    local priv_key_path; priv_key_path="$GENESIS_BE_ROOT_DATA_DIR/node$1/PrivateKey"; local result
    cont_exec $BF_CONT_NAME "bash -c '[ -e \"$priv_key_path\" ] && cat \"$priv_key_path\"'"
    result=$?
    [ $result -ne 0 ] && echo "File '$priv_key_path' doesn't exist @ container '$BF_CONT_NAME'" && return $result
    echo
}

get_priv_keys() {
    if [ -n "$1" ]; then 
        get_priv_key $1
        return $?
    fi
    local num; local wps; local cps; local dbp; local cfp
    read_install_params_to_vars || return 10
    cont_exec $BF_CONT_NAME "bash -c 'for i in \$(seq 1 $num); do echo -n \"\$i: \" && priv_key_path=\"/s/s\$i/PrivateKey\" && [ -e \"\$priv_key_path\" ]  && cat \"\$priv_key_path\" && echo; done'"
}

check_http_priv_key() {
    local result; local out; out=$(get_http_priv_key $@) > /dev/null; result=$?
    [ $result -ne 0 ] && ([ -n "$out" ] && echo "$out" || :) && return $result
    echo "ok"
}

wait_http_priv_key() {
    local url_tpl; url_tpl="$1"
    local idx; idx="$2"
    local codes; codes="$3"
    local min_len; min_len="$4"
    local timeout_secs; [ -z "$5" ] && timeout_secs=15 || timeout_secs=$5
    local wps; wps=$6
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for PrivateKey from backend number '$idx' ..."

    local cnt; cnt=1
    local stop; stop=0
    local result; result=0
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_http_priv_key "$url_tpl" $idx "$codes" $min_len $wps; result=$?
        case $result in
            0|1|2|3|4|5|9|10) stop=1 ;;
            5|6|7|8) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

check_cont_http_len() {
    [ -z "$1" ] && echo "Container name isn't set" && return 1
    [ -z "$2" ] && echo "URL isn't set" && return 2
    [ -z "$3" ] && echo "List of OK codes isn't set" \
        && return 3
    [ -z "$4" ] && echo "Content-Length minimal size (bytes) isn't set" \
        && return 4
    check_cont "$1" > /dev/null; [ $? -ne 0 ] \
        && echo "Container '$1' isn't available " && return 5
    local resp; resp="$(docker exec -t "$1" curl -sv "$2" --stderr -)"
    [ -n "$(echo "$resp" | grep "Could not resolve host")" ] \
        && echo "Could not resolve host" && return 6
    [ -n "$(echo "$resp" | grep "failed: Connection refused")" ] \
        && echo "HTTP Connection refused" && return 7
    local code; code="$(echo "$resp" | $SED_E -n 's/^< HTTP[^ ]* ([0-9]+)[^0-9]+.*$/\1/gp')"
    local c; local result; result=1; IFS=','
    for c in $3; do
        [ "$c" = "$code" ] && result=0 && break
    done
    unset IFS;
    [ $result -ne 0 ] && echo "Bad HTTP Response code '$code' (OK-codes: '$3')" && return 8
    local len; len="$(echo "$resp" | $SED_E -n 's/^[^C]*Content-Length: ([0-9]+)[^0-9]*.*$/\1/gp')"
    [ -z "$len" ] && echo "No Content-Length in HTTP response" && return 9
    [ $len -lt $4 ] && echo "HTTP Content-Length '$len' is lesser than minimal '$3'" && return 10
    echo "ok"
    return 0
}

wait_cont_http_len() {
    local cont_name; cont_name="$1"
    local url; url="$2"
    local codes; codes="$3"
    local min_len; min_len="$4"
    local timeout_secs; [ -z "$5" ] && timeout_secs=15 || timeout_secs="$5"
    local end_time; end_time=$(( $(date +%s) + timeout_secs ))

    echo "Waiting ($timeout_secs seconds) for HTTP response with one of OK-code ($codes) and Content-Length more or equal to '$min_len' bytes to URL '$url' request @ container '$cont_name' ..."

    local cnt; cnt=1
    local stop; stop=0;
    local result; result=0;
    while [ $stop -eq 0 ]; do
        [ $cnt -gt 1 ] && sleep 1
        echo -n "    try $cnt: "
        check_cont_http_len "$cont_name" "$url" "$codes" "$min_len"; result=$?
        case $result in
            0|1|2|3|4|6|9|10) stop=1 ;;
            5|7|8) [ $(date +%s) -lt $end_time ] || stop=1 ;;
        esac
        cnt=$(expr $cnt + 1)
    done
    return $result
}

check_centrifugo_status() {
    echo "Checking centrifugo ..."
    check_cont_http_code $CF_CONT_NAME http://127.0.0.1:8000/connection/ 200
    [ $? -ne 0 ] && echo "centrifugo isn't ready" && exit 200 \
        || echo "Centrifugo ready"
}

wait_centrifugo_status() {
    local result
    wait_cont_http_code $CF_CONT_NAME http://127.0.0.1:8000/connection/ 200 15
    result=$?
    [ $result -ne 0 ] && echo "  centrifugo isn't ready" \
        || echo "  centrifugo ready"
    return $result
}

### Update ### 20180405 ### 08fad ### begin ###

check_backend_apps_status() {
    local num; num=$1
    local app_name; local result; result=0
    echo "Checking backends ..."
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="$GENESIS_BE_BIN_BASENAME" \
            || app_name="$GENESIS_BE_BIN_BASENAME$i"
        echo -n "  backend number $i status: "
        # TODO: use CONT_CLIENT_PORT_SHIFT here
        check_cont_http_len $BF_CONT_NAME http://127.0.0.1:700$i/api/v2/getuid 200,201 100 
    done
    [ $result -ne 0 ] && echo "backends arn't ready" && exit 200 \
        || echo "Backends ready"
}

wait_backend_apps_status() {
    local num; num=$1
    local app_name; local result; result=0
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="$GENESIS_BE_BIN_BASENAME" \
            || app_name="$GENESIS_BE_BIN_BASENAME$i"
        # TODO: use CONT_CLIENT_PORT_SHIFT here
        wait_cont_http_len $BF_CONT_NAME http://127.0.0.1:700$i/api/v2/getuid 200,201 100 20
        [ $? -ne 0 ] && echo "  backend number $i isn't ready" \
            && result=1 \
            || echo "  backend number $i ready"
    done
    [ $result -ne 0 ] && echo "backends arn't ready" && exit 200 \
        || echo "Backends ready"
}

backend_apps_ctl() {
    local num; [ -z "$1" ] && echo "Number of backends isnt' set" && return 1 \
        || num=$1
    local cmd; [ -z "$2" ] && echo "Command isn't set" \
        && echo "Available commands: status, stop, start, restart" \
        && return 2 || cmd="$2"

    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 3

    local app_name; local result; result=0; local rcmd
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="$GENESIS_BE_BIN_BASENAME" \
            || app_name="$GENESIS_BE_BIN_BASENAME$i"
        case "$cmd" in
            status|stop|start|restart)
                rcmd="supervisorctl $cmd $app_name"
                ;;
            *)
                echo "Available commands: status, stop, start, restart"
                return 4
                ;;
        esac
        echo "Backend number $i, starting '$rcmd' ..."
        docker exec -ti $BF_CONT_NAME bash -c "$rcmd"
        [ $? -ne 0 ] && result=4
    done
    return $result
}

### Update ### 20180405 ### 08fad #### end ####

check_frontend_apps_status() {
    local num; num=$1
    local result; result=0
    echo "Checking frontends ..."
    for i in $(seq 1 $num); do
        echo -n "  frontend number $i status: "
        # TODO: use CONT_WEB_PORT_SHIFT here
        check_cont_http_code $BF_CONT_NAME http://127.0.0.1:8$i/ 200,201
    done
    [ $result -ne 0 ] && echo "nginx frontends arn't ready" && exit 210 \
        || echo "Frontends ready"
}

wait_frontend_apps_status() {
    local num; num=$1
    local result; result=0
    for i in $(seq 1 $num); do
        # TODO: use CONT_WEB_PORT_SHIFT here
        wait_cont_http_code $BF_CONT_NAME http://127.0.0.1:8$i/ 200,201 20
        [ $? -ne 0 ] && echo "  nginx frontend number $i isn't ready" \
            && result=1 \
            || echo "  nginx frontend number $i ready"
    done
    [ $result -ne 0 ] && echo "nginx frontends arn't ready" && exit 210 \
        || echo "Frontends ready"
}

### Update ### 20180405 ### 08fad ### begin ###

check_update_mbs_script() {
    local srcs dsts do_copy
    srcs[0]="$SCRIPT_DIR/$BF_CONT_BUILD_DIR$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"
    dsts[0]="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"

    for i in $(seq 0 $(expr ${#srcs[@]} - 1)); do
        do_copy="no"
        docker exec -t $BF_CONT_NAME bash -c "[ -e '${dsts[$i]}' ]" 
        if [ $? -ne 0 ]; then
            do_copy="yes"
        fi
        if [ "$do_copy" = "yes" ] || [ "$FORCE_COPY_MBS_SCRIPT" = "yes" ]; then
            if [ -e "${srcs[$i]}" ]; then
                echo "Copying '${srcs[$i]}' to '${dsts[$i]}' @ '$BF_CONT_NAME' ..."
                docker cp "${srcs[$i]}" $BF_CONT_NAME:${dsts[$i]}
            else
                echo "No '${srcs[$i]}' @ host system. Please create it first." \
                    && return 1
            fi
        fi
    done
}

run_mbs_cmd() {
    local num cmd rmt_path
    check_update_mbs_script || return $?
    rmt_path="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"
    docker exec -ti $BF_CONT_NAME bash $rmt_path $@
}

setup_be_apps() {
    docker exec -t $BF_CONT_NAME bash -c "supervisorctl update && supervisorctl reload"
    local suffix
    [ "$EMPTY_ENV_VARS" = "yes" ] && suffix="-eev" || suffix=""
    run_mbs_cmd create-configs$suffix $1 \
        && run_mbs_cmd gen-keys$suffix $1 \
        && run_mbs_cmd gen-first-block$suffix $1 \
        && run_mbs_cmd init-dbs$suffix $1 \
        && run_mbs_cmd setup-sv-configs $1 \
        docker exec -t $BF_CONT_NAME bash -c "supervisorctl update"
}

start_be_apps() {
    local num; [ -z "$1" ] \
        && echo "The number of backends isn't set" && return 1 \
        || num=$1
    local cps; [ -z "$2" ] && cps=$CLIENT_PORT_SHIFT || cps=$2

    echo "Starting backend applications ..."
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="go-genesis" || app_name="go-genesis$i"
        docker exec -t $BF_CONT_NAME bash -c "supervisorctl start $app_name"
    done
    wait_backend_apps_status $num || return 2
}

stop_be_apps() {
    [ -z "$1" ] && echo "The number of backends isn't set"  && return 1
    echo "Stopping backend applications ..."
    local app_name
    for i in $(seq 1 $1); do
        [ $i -eq 1 ] && app_name="go-genesis" || app_name="go-genesis$i"
        docker exec -t $BF_CONT_NAME bash -c "supervisorctl stop $app_name"
    done
}

setup_fe_apps() {
    local num cps rmt_path
    [ -z "$1" ] && echo "The number of frontends isn't set"  && return 1
    num="$1"
    [ -z "$2" ] && cps="$CLIENT_PORT_SHIFT" || cps="$2"
    check_update_mbs_script || return $?
    rmt_path="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"
    docker exec -ti $BF_CONT_NAME bash -c "$rmt_path setup-frontends $num $cps"
}

start_fe_apps() {
    local num cps stat rmt_path
    [ -z "$1" ] && echo "The number of frontends isn't set"  && return 1
    num="$1"
    [ -z "$2" ] && cps="$CLIENT_PORT_SHIFT" || cps="$2"
    rmt_path="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"
    stat="$(docker exec -ti $BF_CONT_NAME \
        sh -c 'supervisorctl status nginx' | awk '{print $2}')"
    if [ "$stat" != "RUNNING" ]; then
        docker exec -ti $BF_CONT_NAME sh -c 'supervisorctl start nginx'
    fi
    wait_frontend_apps_status $num || return $?
}

### Update ### 20180405 ### 08fad #### end ####

stop_fe_apps() {
    [ -z "$1" ] && echo "The number of frontends isn't set"  && return 1
    echo "Stopping frontend applications ..."
    docker exec -t $BF_CONT_NAME bash -c "supervisorctl stop nginx"
}

check_host_side() {
    local num; ([ -z "$1" ] || [ $1 -eq 0 ]) && return 1 || num=$1
    local wps; [ -z "$2" ] && wps=$WEB_PORT_SHIFT || wps=$2
    local cps; [ -z "$3" ] && cps=$CLIENT_PORT_SHIFT || cps=$3
    local dbp; [ -z "$4" ] && dbp=$DB_PORT || dbp=$4
    local cfp; cfp=$CF_PORT # FIXME: Change to argument

    echo "The host system listens on:"
    echo

    local d_result; d_result=0
    echo "  Database port: $dbp" 
    echo -n "    checking: "
    [ -n "$(get_host_port_proc $dbp)" ] && echo "ok" \
        || (echo "error" && d_result=1)
    echo

    local cf_result; cf_result=0
    echo "  Centrifugo port: $cfp" 
    echo -n "    checking: "
    [ -n "$(check_http_code "http://127.0.0.1:$cfp/connection/" 200)" ] && echo "ok" \
        || (echo "error" && cf_result=1)

    local w_result; w_result=0
    echo
    echo "  Web ports: "
    local w_port
    for i in $(seq 1 $num); do
        w_port=$(expr $i + $wps)
        echo -n "    checking (private key) $w_port: "
        check_http_priv_key "http://127.0.0.1:PORT/keys/PrivateKey" $i 200 64 $wps
        [ $? -ne 0 ] && w_result=1
    done

    local c_result; c_result=0
    echo
    echo "  Client ports: "
    local c_port
    for i in $(seq 1 $num); do
        c_port=$(expr $i + $cps)
        echo -n "    checking (getuid) $c_port: "
        check_http_len http://127.0.0.1:$c_port/api/v2/getuid 200,201 100
        [ $? -ne 0 ] && c_result=1
    done
    echo

    local result; result=0
    [ $d_result -ne 0 ] || [ $w_result -ne 0 ] && result=1
    [ $cf_result -ne 0 ] || [ $cf_result -ne 0 ] && result=3
    [ $c_result -ne 0 ] && result=2
    echo -n "Total check result: "
    [ $result -ne 0 ] && echo "FAILED" || echo "OK"
    return $result
}

### Update ### 20180405 ### 08fad ### begin ###

tail_be_log() {
    local log_basename
    [ -z "$1" ] && echo "Backend's number isn't set" && return 1
    log_basename="node$1.log"

    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 2

    local log_dirname; log_dirname="$GENESIS_BE_ROOT_DATA_DIR/node$1"
    docker exec -t $BF_CONT_NAME bash -c "[ -d '$log_dirname' ]"
    [ $? -ne 0 ] && echo "No log dir '$log_dirname'" && return 3

    local log_path; log_path="$log_dirname/$log_basename"
    docker exec -t $BF_CONT_NAME bash -c "[ -e '$log_path' ]"
    [ $? -ne 0 ] && echo "No log file '$log_path'" && return 4

    docker exec -ti $BF_CONT_NAME bash -c "tail -f $log_path"
}
### Update ### 20180405 ### 08fad #### end ####

### Backends services #### end ####


### Backend ### begin ###

### Update ### 20180405 ### 08fad ### begin ###
build_be() {
    local num; [ -z "$1" ] && echo "Number of backends isnt' set" && return 1 \
        || num=$1

    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 1

    local GOPATH; GOPATH=/go
    docker exec -ti $BF_CONT_NAME bash -c "cd / && go get -d github.com/GenesisKernel/go-genesis && cd /go/src/github.com/GenesisKernel/go-genesis && git checkout $GENESIS_BACKEND_BRANCH && go get github.com/GenesisKernel/go-genesis && ( [ ! -e $GENESIS_BE_BIN_DIR ] && mkdir -p $GENESIS_BE_BIN_DIR || : ) && git checkout | sed -E -n -e \"s/^([^']+)'([^']+)'/\2/p\" | sed -E -n \"s/origin\/([^.]+)\./\1/p\" > $GENESIS_BE_BIN_DIR.git_branch && git log --pretty=format:'%h' -n 1 > $GENESIS_BE_BIN_DIR.git_commit && ( [ ! -e $GENESIS_BE_ROOT_DATA_DIR/node1 ] && mkdir -p $GENESIS_BE_ROOT_DATA_DIR/node1 || : ) && mv $GOPATH/bin/go-genesis $GENESIS_BE_BIN_DIR.git_branch"

    backend_apps_ctl $num restart
}
### Update ### 20180405 ### 08fad #### end ####

clean_be_build() {
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 1
    docker exec -ti $BF_CONT_NAME bash -c "rm -rf /go"
}

### Update ### 20180405 ### 08fad ### begin ###

get_be_ver() {
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" && return 1
    docker exec -ti $BF_CONT_NAME bash -c "$GENESIS_BE_BIN_PATH -noStart 2>&1 | sed -E -n 's/^.*version\W+([0-9a-zA-Z\.\-]+)\W+.*/\1/pg'"
}

get_be_git_ver() {
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" && return 1
    docker exec -ti $BF_CONT_NAME bash -c "[ -e $GENESIS_BE_BIN_PATH.git_branch ] && echo -n 'Git branch: ' && cat $GENESIS_BE_BIN_PATH.git_branch; [ -e $GENESIS_BE_BIN_PATH.git_commit ] && echo -n 'Git commit: ' && cat $GENESIS_BE_BIN_PATH.git_commit && echo"
}

### Update ### 20180405 ### 08fad #### end ####

### Backend #### end ####


### Frontend ### begin ###

### Update ### 20180405 ### 08fad ### begin ###

build_fe() {
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 1

    docker exec -ti $BF_CONT_NAME bash -c "cd / && ([ -e $GENESIS_FE_SRC_DIR ] && rm -rf $GENESIS_FE_SRC_DIR || : ) && git clone --recursive https://github.com/GenesisKernel/genesis-front $GENESIS_FE_SRC_DIR && cd $GENESIS_FE_SRC_DIR && git checkout $GENESIS_FRONT_BRANCH && git pull origin $GENESIS_FRONT_BRANCH && git branch | sed -E -n 's/.* (v[0-9a-zA-Z\-\.\_]+)\)/\1/p' > $GENESIS_FE_SRC_DIR.git_branch && git log --pretty=format:'%h' -n 1 > $GENESIS_FE_SRC_DIR.git_commit && yarn install && yarn build"
}

clean_fe_build() {
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 1
    docker exec -ti $BF_CONT_NAME bash -c \
        "find $GENESIS_FE_SRC_DIR -maxdepth 1 -mindepth 1 -not -name 'build*' -exec rm -rf {} \;"
}


get_fe_ver() {
    echo "$GENESIS_FRONT_BRANCH"
}

get_fe_git_ver() {
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -ne 0 ] \
        && echo "Backend/frontend container isn't ready" \
        && return 1

    docker exec -ti $BF_CONT_NAME bash -c "[ -e $GENESIS_FE_SRC_DIR.git_branch ] && echo -n 'Git branch: ' && cat $GENESIS_FE_SRC_DIR.git_branch; [ -e $GENESIS_FE_SRC_DIR.git_commit ] && echo -n 'Git commit: ' && cat $GENESIS_FE_SRC_DIR.git_commit && echo"
}
### Update ### 20180405 ### 08fad #### end ####

### Frontend #### end ####


### Misc ### begin ###

check_num_param() {
    [ -z "$1" ] && echo "The number of clients/backends is not set" && exit 100
    [ $1 -gt 5 ] \
        && echo "The maximum number of clients/backends is 5" && exit 101
}

save_install_params() {
    (
        update_global_home_var
        run_as_orig_user "[ -e \"$HOME/.apla_quick_start\" ] && rm \"$HOME/.apla_quick_start\""
        run_as_orig_user "echo \"$@\" > \"$HOME/.genesis_quick_start\""
    )
}

show_install_params() {
    (
        update_global_home_var
        if [ -e "$HOME/.genesis_quick_start" ]; then
            cat "$HOME/.genesis_quick_start"
        elif [ -e "$HOME/.apla_quick_start" ]; then
            cat "$HOME/.apla_quick_start"
        else
            echo "No install parameters found."
        fi
    )
}

read_install_params() {
    (
        update_global_home_var
        if [ -e "$HOME/.genesis_quick_start" ]; then
            cat "$HOME/.genesis_quick_start"
        elif [ -e "$HOME/.apla_quick_start" ]; then
            cat "$HOME/.apla_quick_start"
        else
            echo "No install parameters found."
        fi
    )
}

read_install_params_to_vars() {
    # Please define variables 'num', 'wps', 'cps', 'dbp' before run this function"
    params="$(read_install_params)"
    [ -z "$params" ] \
        && echo "No install parameters found. Please start install first" \
        && return 1

    local cnt; cnt=0
    for param in $params; do
        case $cnt in
            0) num=$param ;;
            1) wps=$param ;;
            2) cps=$param ;;
            3) dbp=$param ;;
        esac
        cnt=$(expr $cnt + 1)
    done
}

test_install_params() {
    echo "Reading params: '$@'"
    echo "arg1: $1"
    echo "arg2: $2"
    echo "arg3: $3"
    echo "arg4: $4"
}

clear_install_params() {
    (
        update_global_home_var
        [ -e "$HOME/.apla_quick_start" ] && rm "$HOME/.apla_quick_start"
        [ -e "$HOME/.genesis_quick_start" ] && rm "$HOME/.genesis_quick_start"
    )
}

delete_install() {
    stop_clients
    remove_cont $BF_CONT_NAME
    remove_cont $CF_CONT_NAME
    remove_cont $DB_CONT_NAME
}

### Update ### 20180405 ### 08fad ### begin ###

start_update_full_nodes() {
    local num rmt_path
    num=$1
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of backends is not set or wrong: '$num'" \
        && return 1
    check_update_mbs_script || return $?
    rmt_path="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"

    echo "Starting 'update full nodes' ..."
    docker exec -t $BF_CONT_NAME bash $rmt_path update-full-nodes-v1 $num
    [ $? -ne 0 ] \
        && echo "Full nodes updating isn't completed" && return 3
    echo "Full nodes updating is completed"
    return 0
}

start_update_keys() {
    local num rmt_path
    num=$1
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of backends is not set or wrong: '$num'" \
        && return 1
    check_update_mbs_script || return $?
    rmt_path="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"

    echo "Starting 'update keys' ..."
    docker exec -t $BF_CONT_NAME bash $rmt_path update-keys $num
    [ $? -ne 0 ] \
        && echo "Keys updating isn't completed" && return 3
    echo "Keys updating is completed"
    return 0
}

### Update ### 20180405 ### 08fad #### end ####

get_demo_apps_url_from_dockerfile() {
    local df_path; df_path="$SCRIPT_DIR/$BF_CONT_BUILD_DIR/Dockerfile"
    [ ! -e "$df_path" ] && return 1
    local url; url="$($SED_E -n 's/^ENV GENESIS_DEMO_APPS_URL (.*)$/\1/p' "$df_path" | tail -n 1)"
    [ -n "$url" ] && echo "$url" || return 2
}

### Update ### 20180405 ### 08fad ### begin ###
copy_import_demo_apps_scripts() {

    local srcs; local dsts;

    srcs[0]="$SCRIPT_DIR/$BF_CONT_BUILD_DIR$GENESIS_SCRIPTS_DIR/genesis_api_client.py"
    dsts[0]="$GENESIS_SCRIPTS_DIR/genesis_api_client.py"

    srcs[1]="$SCRIPT_DIR/$BF_CONT_BUILD_DIR$GENESIS_SCRIPTS_DIR/import_demo_apps.py"
    dsts[1]="$GENESIS_SCRIPTS_DIR/import_demo_apps.py"

    srcs[2]="$SCRIPT_DIR/$BF_CONT_BUILD_DIR$GENESIS_SCRIPTS_DIR/import_demo_apps.sh"
    dsts[2]="$GENESIS_SCRIPTS_DIR/import_demo_apps.sh"

    local do_copy

    for i in $(seq 0 $(expr ${#srcs[@]} - 1)); do
        do_copy="no"
        docker exec -t $BF_CONT_NAME bash -c "[ -e '${dsts[$i]}' ]" 
        if [ $? -ne 0 ]; then
            do_copy="yes"
        fi
        if [ "$do_copy" = "yes" ] \
            || [ "$FORCE_COPY_IMPORT_DEMO_APPS_SCRIPTS" = "yes" ]; then

            if [ -e "${srcs[$i]}" ]; then
                echo "Copying '${srcs[$i]}' to '${dsts[$i]}' @ '$BF_CONT_NAME' ..."
                docker cp "${srcs[$i]}" $BF_CONT_NAME:${dsts[$i]}
            else
                echo "No '${srcs[$i]}' @ host system. Please create it first." \
                    && return 1
            fi
        fi
    done
}

copy_import_demo_apps_data_files() {

    local srcs; local dsts;
    
    srcs[0]="$SCRIPT_DIR/$BF_CONT_BUILD_DIR$GENESIS_APPS_DIR/demo_apps.json"
    dsts[0]="$GENESIS_APPS_DIR/demo_apps.json"

    srcs[1]="$SCRIPT_DIR/$BF_CONT_BUILD_DIR$GENESIS_APPS_DIR/demo_apps.url"
    dsts[1]="$GENESIS_APPS_DIR/demo_apps.url"

    local do_copy

    for i in $(seq 0 $(expr ${#srcs[@]} - 1)); do
        do_copy="no"
        docker exec -t $BF_CONT_NAME bash -c "[ -e '${dsts[$i]}' ]" 
        if [ $? -ne 0 ]; then
            do_copy="yes"
        fi
        if [ "$do_copy" = "yes" ] \
            || [ "$FORCE_COPY_IMPORT_DEMO_APPS_DATA_FILES" = "yes" ]; then

            if [ -e "${srcs[$i]}" ]; then
                echo "Copying '${srcs[$i]}' to '${dsts[$i]}' @ '$BF_CONT_NAME' ..."
                docker exec -ti $BF_CONT_NAME bash "[ ! -e '$GENESIS_APPS_DIR' ] && mkdir -p '$GENESIS_APPS_DIR'"
                docker cp "${srcs[$i]}" $BF_CONT_NAME:${dsts[$i]}
            else
                echo "No '${srcs[$i]}' @ host system. Skipping it ..."
            fi
        fi
    done
}

start_import_demo_apps() {
    echo "Preparing for importing of demo apps ..."
    check_cont "$BF_CONT_NAME" > /dev/null; [ $? -ne 0 ] \
        && echo "Container '$BF_CONT_NAME' isn't available " && return 1

    local rmt_path

    copy_import_demo_apps_scripts|| return 2
    copy_import_demo_apps_data_files || return 3
    check_update_mbs_script || return $?
    rmt_path="$GENESIS_SCRIPTS_DIR/manage_bf_set.sh"

    local up_da; up_da=1

    local da_path; da_path="$GENESIS_APPS_DIR/demo_apps.json"
    docker exec -t $BF_CONT_NAME bash -c "[ -e $da_path ]" 
    if [ $? -ne 0 ]; then
        up_da=0
    fi

    local result
    local da_url; da_url="$GENESIS_DEMO_APPS_URL"
    local dau_path; dau_path="$GENESIS_APPS_DIR/demo_apps.url"

    docker exec -t $BF_CONT_NAME bash -c "[ -e $dau_path ]" 
    if [ $? -eq 0 ]; then
        local da_url_c; da_url_c="$(docker exec -t $BF_CONT_NAME bash -c "head -n 1 $dau_path")" 
        da_url_c="${da_url_c%\\n}"
        [ "$da_url" != "$da_url_c" ] \
            && echo "Demo apps URL '$da_url_c' from '$dau_path' @ container '$BF_CONT_NAME' isn't equal to '$da_url'. Update required ..." \
            && up_da=0
    else
        echo "'$dau_path' not found @ container '$BF_CONT_NAME'"
        up_da=0
    fi
    
    if [ $up_da -eq 0 ]; then
        echo "Updating '$da_path' @ container '$BF_CONT_NAME' by data from '$da_url' ..."
        docker exec -t "$BF_CONT_NAME" bash -c "curl -L -o $da_path $da_url"; result=$?
        [ $result -ne 0 ] && echo "Can't download '$da_url' to '$da_path' @ container '$BF_CONT_NAME'" && return 3
        echo "Updating '$dau_path' @ container '$BF_CONT_NAME' by URL '$da_url' ..."
        docker exec -t "$BF_CONT_NAME" bash -c "echo -n '$da_url' > '$dau_path'"; result=$?
        [ $result -ne 0 ] && echo "Can't update $dau_path' @ container '$BF_CONT_NAME'" && return 4
    else
        echo "'$da_path' is up to date"
    fi

    echo "Starting importing of demo apps with a data from '$da_url' ..."
    docker exec -ti $BF_CONT_NAME bash $GENESIS_SCRIPTS_DIR/manage_bf_set.sh import-demo-apps
    [ $? -ne 0 ] \
        && echo "Demo apps importing isn't completed" && return 3
    echo "Demo apps importing is completed"
    return 0
}

get_demo_apps_ver() {
    check_cont "$BF_CONT_NAME" > /dev/null; [ $? -ne 0 ] \
        && echo "Container '$BF_CONT_NAME' isn't available " && return 1

    local dau_path; dau_path="$GENESIS_APPS_DIR/demo_apps.url"
    docker exec -t $BF_CONT_NAME bash -c \
        "[ -f '$dau_path' ] && cat '$dau_path'"
    [ $? -ne 0 ] \
        && echo "No or inaccessible '$dau_path' @ $BF_CONT_NAME" && return 2
}

### Update ### 20180405 ### 08fad #### end ####


start_install() {
    local num; num=$1
    local wps; wps=$2
    local cps; cps=$3
    local dbp; dbp=$4
    local cfp; cfp=$CF_PORT # FIXME: change to argument

    local tot_cont_res; tot_cont_res=0

    local db_cont_res; check_cont $DB_CONT_NAME > /dev/null; db_cont_res=$? 
    [ $db_cont_res -ne 1 ] \
        && echo "DB container already exists. " \
        && tot_cont_res=1

    local cf_cont_res; check_cont $CF_CONT_NAME > /dev/null; cf_cont_res=$? 
    [ $cf_cont_res -ne 1 ] \
        && echo "Centrifugo container already exists. " \
        && tot_cont_res=1

    local bf_cont_res; check_cont $BF_CONT_NAME > /dev/null; bf_cont_res=$? 
    [ $bf_cont_res -ne 1 ] \
        && echo "Backend/Frontend container already exists. " \
        && tot_cont_res=1

    if [ $tot_cont_res -ne 0 ]; then
        echo -n "Do you want to stop all running clients, delete containers and start a new installation? [y/N] "
        local stop; stop=0
        while [ $stop -eq 0 ]; do
            read -n 1 answ
            case $answ in
                y|Y)
                    echo
                    echo "OK, stopping clients, removing container ..."
                    delete_install
                    stop=1
                    ;;
                n|N)
                    echo
                    echo "OK, stopping installation ..."
                    return 5
                    ;;
            esac
        done
    fi
    
    start_db_cont $dbp

    wait_cont_proc $DB_CONT_NAME postgres 25
    [ $? -ne 0 ] \
        && echo "Postgres process isn't available" && return 10 \
        || echo "Postgres ready"

    wait_db_exists postgres 45
    [ $? -ne 0 ] \
        && echo "postgres database isn't available" && return 11 \
        || echo "postgres database ready"

    wait_db_exists template0 45
    [ $? -ne 0 ] \
        && echo "template0 database isn't available" && return 12 \
        || echo "template0 database ready"

    wait_db_exists template1 45
    [ $? -ne 0 ] \
        && echo "template1 database isn't available" && return 13 \
        || echo "template1 database ready"

    echo

    create_dbs $num 25
    [ $? -ne 0 ] \
        && echo "Backend databases creation failed" && return 14 \
        || echo "Backend databases creation compete"

    wait_dbs $num 25
    [ $? -ne 0 ] \
        && echo "Backend databases ant't available" && return 14 \
        || echo "Backend databases ready"
    echo

    start_cf_cont $cfp

    wait_cont_proc $CF_CONT_NAME centrifugo 10
    [ $? -ne 0 ] \
        && echo "Centrifugo process isn't available" && return 21 \
        || echo "Centrifugo ready"
    echo

    wait_centrifugo_status || return 21
    echo

    start_bf_cont $num $wps $cps

    wait_cont_proc $BF_CONT_NAME supervisord 15
    [ $? -ne 0 ] \
        && echo "Backend's supervisord isn't available" && return 21 \
        || echo "Backend's supervisord ready"

    wait_cont_proc $BF_CONT_NAME nginx 15
    [ $? -ne 0 ] \
        && echo "Frontend's nginx isn't available" && return 22 \
        || echo "Frontend's nginx ready"
    echo

    ### Update ### 20180405 ### 08fad ### begin ###

    setup_be_apps $num $cps
    [ $? -ne 0 ] \
        && echo "Backend applications setup isn't completed" && return 23 \
        || echo "Backend applications setup is completed"
    echo

    ### Update ### 20180405 ### 08fad #### end ####

    start_be_apps $num $cps
    [ $? -ne 0 ] \
        && echo "Backend applications arn't available" && return 23 \
        || echo "Backend applications ready"
    echo

    setup_fe_apps $num $cps
    [ $? -ne 0 ] \
        && echo "Fronend applications setup isn't completed" && return 24 \
        || echo "Fronend applications setup is completed"
    echo

    start_fe_apps $num $cps
    [ $? -ne 0 ] \
        && echo "Fronend applications arn't available" && return 24 \
        || echo "Fronend applications are ready"
    echo

    start_update_keys $num || return 26
    echo

    start_update_full_nodes $num || return 25
    echo

    start_import_demo_apps || return 27
    echo

    echo "Comparing backends 1_keys ..."
    cmp_keys $num || return 28
    echo

    echo "Comparing backends first blocks ..."
    cmp_first_blocks $num || return 29
    echo

    check_host_side $num $wps $cps $dbp
    [ $? -ne 2 ] && start_clients $num $wps $cps
    # FIXME: add cfp
}

stop_all() {
    stop_clients
    check_cont $BF_CONT_NAME > /dev/null
    [ $? -eq 0 ] \
        && echo "Stopping $BF_CONT_NAME ..." && docker stop $BF_CONT_NAME
    check_cont $CF_CONT_NAME > /dev/null
    [ $? -eq 0 ] \
        && echo "Stopping $CF_CONT_NAME ..." && docker stop $CF_CONT_NAME
    check_cont $DB_CONT_NAME > /dev/null
    [ $? -eq 0 ] \
        && echo "Stopping $DB_CONT_NAME ..." && docker stop $DB_CONT_NAME
}

start_all() {
    local num
    local wps
    local cps
    local dbp
    local cfp; cfp=$CF_PORT # FIXME: Change to argument

    read_install_params_to_vars || return 1

    start_db_cont $dbp

    wait_cont_proc $DB_CONT_NAME postgres 15
    [ $? -ne 0 ] \
        && echo "Postgres process isn't available" && return 10 \
        || echo "Postgres ready"

    wait_db_exists postgres 35
    [ $? -ne 0 ] \
        && echo "postgres database isn't available" && return 11 \
        || echo "postgres database ready"

    wait_db_exists template0 35
    [ $? -ne 0 ] \
        && echo "template0 database isn't available" && return 12 \
        || echo "template0 database ready"

    wait_db_exists template1 35
    [ $? -ne 0 ] \
        && echo "template1 database isn't available" && return 13 \
        || echo "template1 database ready"

    echo

    wait_dbs $num 15
    [ $? -ne 0 ] \
        && echo "Backend databases ant't available" && return 14 \
        || echo "Backend databases ready"
    echo

    start_cf_cont $cfp

    wait_cont_proc $CF_CONT_NAME centrifugo 10
    [ $? -ne 0 ] \
        && echo "Centrifugo process isn't available" && return 21 \
        || echo "Centrifugo ready"
    echo

    start_bf_cont $num $wps $cps

    wait_cont_proc $BF_CONT_NAME supervisord 15
    [ $? -ne 0 ] \
        && echo "Backend's supervisord isn't available" && return 21 \
        || echo "Backend's supervisord ready"

    wait_cont_proc $BF_CONT_NAME nginx 15
    [ $? -ne 0 ] \
        && echo "Backend's nginx isn't available" && return 22 \
        || echo "Backend's nginx ready"
    echo

    wait_centrifugo_status || return 5
    echo

    wait_backend_apps_status $num || return 2
    echo

    wait_frontend_apps_status $num || return 3
    echo

    check_host_side $num $wps $cps $dbp
    [ $? -ne 2 ] && start_clients $num $wps $cps
    # FIXME: Add $cfp param
}

show_status() {
    local num
    local wps
    local cps
    local dbp

    read_install_params_to_vars || return 1


    local cont_status; cont_status=0
    echo
    echo -n "Dababase container status: "
    get_cont_status $DB_CONT_NAME; cont_status=$?
    echo -n "Centrifugo container status: "
    get_cont_status $CF_CONT_NAME; cont_status=$?
    echo -n "Backends/Frontends container status: "
    get_cont_status $BF_CONT_NAME; cont_status=$?
    echo

    [ $cont_status -ne 0 ] \
        && echo "Containers status: FAILED" \
        && return 2

    check_centrifugo_status
    echo

    check_backend_apps_status $num
    echo

    check_frontend_apps_status $num
    echo

    check_host_side $num $wps $cps $dbp
}

### Docker Images ### begin ###

show_all_docker_images() {
    local img_name
    for img_name in ${BF_CONT_IMAGE%%:*} ${DB_CONT_IMAGE%%:*} ${CF_CONT_IMAGE%%:*}; do
        docker images -f reference="$img_name:*" --format '{{.ID}} {{.Repository}} {{.Tag}}'
    done
}

show_docker_images() {
    local img_name
    for img_name in ${BF_CONT_IMAGE} ${DB_CONT_IMAGE} ${CF_CONT_IMAGE}; do
        docker images -f reference="$img_name" --format '{{.ID}} {{.Repository}} {{.Tag}}'
    done
}

show_prev_docker_images() {
    local img_name
    for img_name in ${BF_CONT_PREV_IMAGE} ${DB_CONT_PREV_IMAGE} ${CF_CONT_PREV_IMAGE}; do
        docker images -f reference="$img_name" --format '{{.ID}} {{.Repository}} {{.Tag}}'
    done
}

### Docker Images #### end ####


### Dockerfile ### begin ###

update_bf_dockerfile() {
    local df; df="$SCRIPT_DIR/$BF_CONT_BUILD_DIR/Dockerfile"
    [ ! -e "$df" ] \
           && echo "No '$df' file. Please create it first" && return 1

    local sed_i_cmd
    local os_type; os_type="$(get_os_type)"
    case $os_type in
        linux) sed_i_cmd="$SED_E -i" ;;
        mac) sed_i_cmd="$SED_E -i .bak" ;;
        *)
            echo "Sorry, but $os_type is not supported yet"
            exit 23
            ;;
    esac

    sed_cmd="$sed_i_cmd 's/(ENV[ ]+GOLANG_VER[ ]+)([0-9a-zA-Z\.\-]+)$/\1$GOLANG_VER/' $df"
    #echo "sed_cmd: $sed_cmd"
    eval "$sed_cmd"

    local be_br_esc; be_br_esc="$(echo "$GENESIS_BACKEND_BRANCH" | $SED_E 's/\//\\\//g')"
    sed_cmd="$sed_i_cmd -e 's/(ENV[ ]+GENESIS_BACKEND_BRANCH[ ]+)([0-9a-zA-Z\.\_\-\:\/]+)[ ]*$/\1$be_br_esc/' $df"
    #echo "sed_cmd: $sed_cmd"
    eval "$sed_cmd"

    local demo_apps_url_esc; demo_apps_url_esc="$(echo "$GENESIS_DEMO_APPS_URL" | $SED_E 's/\//\\\//g')"
    sed_cmd="$sed_i_cmd 's/(ENV[ ]+GENESIS_DEMO_APPS_URL[ ]+)([^ ]+)[ ]*$/\1$demo_apps_url_esc/' $df"
    #echo "sed_cmd: $sed_cmd"
    eval "$sed_cmd"
}

### Dockerfile #### end ####


### Help ### begin ###

### Update ### 20180405 ### 08fad ### begin ###
show_usage_help() {
    echo
    echo "Usage: $(basename "$0") <command> <parameter>"
    echo
    echo "  Commands:"
    echo
    echo "  install NUM [WPS] [CPS] [DBP]"
    echo "    Install Docker, Genesis Client, database and backend containers"
    echo "      NUM - number of clients/backends (mandatory)"
    echo "      WPS - web port shift (optional, default: $WEB_PORT_SHIFT)"
    echo "      CPS - client port shift (optional, default: $CLIENT_PORT_SHIFT)"
    echo "      DBP - database host port (optional, default: $DB_PORT)"
    echo "    Example:"
    echo "      $(basename "$0") install 3 8000 17000"
    echo "      will install Docker, Genesis Client, start database container,"
    echo "      start container with 3 frontends (web ports 8001, 8002, 8003)"
    echo "      and 3 backends (client ports 17001, 17002, 17003),"
    echo "      setup database for them and finally start 3 clients"
    echo
    echo "  reinstall"
    echo "    Stop clients, remove existing containers and start a new installation"
    echo "    with the last installation parameters"
    echo
    echo "  params"
    echo "    Show install params"
    echo
    echo "  start"
    echo "    Start containers, apps and clients"
    echo
    echo "  stop"
    echo "    Stop clients and containers"
    echo
    echo "  status"
    echo "    Show status of containers, databases, backends and frontends"
    echo
    echo "  start-clients"
    echo "    Start clients with latest installation parameters"
    echo 
    echo "  stop-clients"
    echo "    Stop clients"
    echo 
    echo "  restart-clients"
    echo "    Restart clients"
    echo 
    echo "  be-apps-ctl [CMD]"
    echo "    Control backend applications."
    echo "    CMD - command, available: status, start, stop, restart"
    echo 
    echo "  block-chain-count"
    echo "    Show the number of records in each backend's block_chain table"
    echo 
    echo "  db-shell [BE_NUM]"
    echo "    Run database shell (psql) connected to backend's database"
    echo "    BE_NUM - backend's number"
    echo
    echo "  db-query [BE_NUM]"
    echo "    Run SQL-query at backend's database"
    echo "    BE_NUM - backend's number"
    echo
    echo "  delete"
    echo "    Stop clients and delete all Genesis-related docker containers"
    echo
    echo "  delete-all"
    echo "    Stop clients and delete all Genesis-related docker containers and images"
    echo
    echo "  uninstall-docker"
    echo "    Docker unintaller for macOS"
    echo
    echo "  uninstall-client"
    echo "    Client unintaller for macOS"
    echo
    echo "  build-images"
    echo "    Build all (database and backend/frontend) container images"
    echo
    echo "  build-bf-image"
    echo "    Build backend/frontend container image"
    echo
    echo "  build-db-image"
    echo "    Build database container image"
    echo
    echo "  build-cf-image"
    echo "    Build centrifugo container image"
    echo
}
### Update ### 20180405 ### 08fad #### end ####

### Help #### end ####


### Run ### begin ###

pre_command() {
    check_requirements
}

[ "$0" = "$BASH_SOURCE" ] && pre_command && case $1 in

    ### OS ### begin ###

    is-root)
        is_root
        ;;

    as-user)
        shift 1
        run_as_orig_user $@
        ;;

    create-dl-dir)
        create_downloads_dir
        ;;

    homedir)
        shift 1
        get_orig_user_homedir
        ;;

    os-type)
        get_os_type
        ;;

    linux-dist)
        get_linux_dist
        ;;

    check-min-req)
        check_min_req
        ;;

    ### OS #### end ####


    ### Disk, FS ### begin ###

    dev-by-path)
        get_mnt_dev_by_path "$2"
        ;;

    fs-by-path)
        get_fs_type_by_path "$2"
        ;;

    ### Disk, FS #### end ####


    ### Docker ### begin ###

    uninstall-docker)
        uninstall_docker
        ;;

    install-docker)
        check_run_as_root
        install_mac_docker_directly
        ;;

    check-docker-proc)
        check_proc docker
        ;;

    wait-docker-proc)
        wait_proc docker
        ;;

    check-docker-ready)
        check_docker_ready_status
        ;;

    wait-docker-ready)
        wait_docker_ready_status
        ;;

    download-client)
        download_and_check_dmg "$CLIENT_DMG_DL_URL" "$CLIENT_DMG_BASENAME"
        echo "res: $?"
        ;;

    install-client)
        check_run_as_root
        install_mac_client_directly
        ;;

    uninstall-client)
        stop_clients
        uninstall_client
        ;;

    start-docker)
        check_run_as_root
        start_docker
        ;;

    ### Docker #### end ####


    ### Host ports ### begin ###

    host-port-proc)
        get_host_port_proc $2
        ;;

    check-host-ports)
        check_host_ports $2 $3 $4 $5
        ;;

    check-host-side)
        check_host_side $2 $3 $4 $5
        ;;

    ### Host ports #### end ####

    ### Clients ### begin ###

    install-client)
        install_linux_client_directly
        ;;

    start-clients)
        params="$(read_install_params)"
        [ -z "$params" ] \
            && echo "No install parameters found. Please start install first" \
            && exit 50
        start_clients $params
        ;;

    stop-clients)
        stop_clients
        ;;

    restart-clients)
        stop_clients
        params="$(read_install_params)"
        [ -z "$params" ] \
            && echo "No install parameters found. Please start install first" \
            && exit 50
        start_clients $params
        ;;

    ### Clients #### end ####


    ### DB container ### begin ###

    prep-db-cont)
        check_run_as_root
        prep_cont_for_inspect $DB_CONT_NAME
        ;;

    db-cont-bash|db-cont-sh|db-cont-shell)
        check_run_as_root
        cont_bash $DB_CONT_NAME
        ;;

    start-db-cont)
        check_run_as_root
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        start_db_cont $dbp
        ;;

    stop-db-cont)
        check_run_as_root
        docker stop $DB_CONT_NAME
        ;;

    delete-db-cont)
        check_run_as_root
        remove_cont $DB_CONT_NAME
        ;;

        
    ### DB Container #### end ####


    ### DB Image ### begin ###

    delete-db-image)
        check_run_as_root
        docker rmi -f $DB_CONT_IMAGE
        ;;

    build-db-image)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $DB_CONT_NAME -f $DB_CONT_BUILD_DIR/Dockerfile $DB_CONT_BUILD_DIR/.)
        ;;

    delete-prev-db-image)
        check_run_as_root
        docker rmi -f $DB_CONT_PREV_IMAGE
        ;;

    pull-db-image)
        check_run_as_root
        docker pull $DB_CONT_IMAGE
        ;;
        
    pull-prev-db-image)
        check_run_as_root
        docker pull $DB_CONT_PREV_IMAGE
        ;;

    tag-local-db-image)
        check_run_as_root
        docker tag $DB_CONT_NAME $DB_CONT_IMAGE
        ;;

    tag-prev-db-image)
        check_run_as_root
        docker tag $DB_CONT_PREV_IMAGE $DB_CONT_IMAGE
        ;;

    push-db-image)
        check_run_as_root
        docker push $DB_CONT_IMAGE
        ;;

    up-prev-db-image)
        check_run_as_root
        docker pull $DB_CONT_PREV_IMAGE
        docker tag $DB_CONT_PREV_IMAGE $DB_CONT_IMAGE
        echo
        echo -n "Are you sure to push '$DB_CONT_IMAGE' image to docker hub [y/n]? "
        read -n 1 answ
        case $answ in
            y|Y) docker push $DB_CONT_IMAGE ;;
            *) echo; echo "OK, skipping the pushing ..." ;;
        esac
        ;;

    ### DB Image #### end ####


    ### BF container ### begin ###

    start-bf-cont)
        check_run_as_root
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        start_bf_cont $num $wps $cps
        ;;

    stop-bf-cont)
        check_run_as_root
        docker stop $BF_CONT_NAME
        ;;

    restart-bf-cont)
        check_run_as_root
        docker stop $BF_CONT_NAME
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        start_bf_cont $num $wps $cps
        ;;

    prep-bf-cont)
        check_run_as_root
        prep_cont_for_inspect $BF_CONT_NAME
        ;;

    bf-cont-bash|bf-cont-sh|bf-cont-shell)
        check_run_as_root
        cont_bash $BF_CONT_NAME
        ;;

    delete-bf-cont)
        check_run_as_root
        remove_cont $BF_CONT_NAME
        ;;
        
    ### BF Container #### end ####

    
    ### BF Dockerfile ### begin ###

    up-bf-dockerfile)
        update_bf_dockerfile || exit 41
        ;;

    ### BF Dockerfile #### end ####


    ### FE Image ### begin ###

    build-fe-image)
        check_run_as_root
        #update_fe_dockerfile || exit 41
        (cd "$script_dir" \
            && docker build -t $FE_CONT_NAME -f $FE_CONT_BUILD_DIR/Dockerfile $FE_CONT_BUILD_DIR/.)
        ;;

    ### FE Image #### end ####

    ### BE Image ### begin ###

    build-be-image)
        check_run_as_root
        #update_fe_dockerfile || exit 41
        (cd "$script_dir" \
            && docker build -t $BE_CONT_NAME -f $BE_CONT_BUILD_DIR/Dockerfile $BE_CONT_BUILD_DIR/.)
        ;;

    ### BE Image #### end ####


    ### BF Image ### begin ###

    build-bf-image)
        check_run_as_root
        update_bf_dockerfile || exit 41
        (cd "$script_dir" \
            && docker build -t $BF_CONT_NAME -f $BF_CONT_BUILD_DIR/Dockerfile $BF_CONT_BUILD_DIR/.)
        ;;

    delete-bf-image)
        check_run_as_root
        docker rmi -f $BF_CONT_IMAGE
        ;;

    delete-prev-bf-image)
        check_run_as_root
        docker rmi -f $BF_CONT_PREV_IMAGE
        ;;

    pull-bf-image)
        check_run_as_root
        docker pull $BF_CONT_IMAGE
        ;;
        
    pull-prev-bf-image)
        check_run_as_root
        docker pull $BF_CONT_PREV_IMAGE
        ;;

    tag-local-bf-image)
        check_run_as_root
        docker tag $BF_CONT_NAME $BF_CONT_IMAGE
        ;;

    tag-prev-bf-image)
        check_run_as_root
        docker tag $BF_CONT_PREV_IMAGE $BF_CONT_IMAGE
        ;;

    push-bf-image)
        check_run_as_root
        docker push $BF_CONT_IMAGE
        ;;

    up-prev-bf-image)
        check_run_as_root
        docker pull $BF_CONT_PREV_IMAGE
        docker tag $BF_CONT_PREV_IMAGE $CF_CONT_IMAGE
        echo
        echo -n "Are you sure to push '$BF_CONT_IMAGE' image to docker hub [y/n]? "
        read -n 1 answ
        case $answ in
            y|Y) docker push $BF_CONT_IMAGE ;;
            *) echo; echo "OK, skipping the pushing ..." ;;
        esac
        ;;

    ### BF Image #### end ####


    ### CF container ### begin ###

    start-cf-cont)
        check_run_as_root
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        start_cf_cont
        ;;

    stop-cf-cont)
        check_run_as_root
        docker stop $CF_CONT_NAME
        ;;

    restart-cf-cont)
        check_run_as_root
        docker stop $CF_CONT_NAME
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        start_cf_cont $num $wps $cps
        ;;

    prep-cf-cont)
        check_run_as_root
        prep_cont_for_inspect_centos7 $CF_CONT_NAME
        ;;

    cf-cont-bash|cf-cont-sh|cf-cont-shell)
        check_run_as_root
        cont_bash $CF_CONT_NAME
        ;;

    delete-cf-cont)
        check_run_as_root
        remove_cont $CF_CONT_NAME
        ;;
        
    ### CF Container #### end ####


    ### CF Image ### begin ###

    build-cf-image)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $CF_CONT_NAME -f $CF_CONT_BUILD_DIR/Dockerfile $CF_CONT_BUILD_DIR/.)
        ;;

    delete-cf-image)
        check_run_as_root
        docker rmi -f $CF_CONT_IMAGE
        ;;

    delete-prev-cf-image)
        check_run_as_root
        docker rmi -f $CF_CONT_PREV_IMAGE
        ;;

    pull-cf-image)
        check_run_as_root
        docker pull $CF_CONT_IMAGE
        ;;
        
    pull-prev-cf-image)
        check_run_as_root
        docker pull $CF_CONT_PREV_IMAGE
        ;;

    tag-local-cf-image)
        check_run_as_root
        docker tag $CF_CONT_NAME $CF_CONT_IMAGE
        ;;

    tag-prev-cf-image)
        check_run_as_root
        docker tag $CF_CONT_PREV_IMAGE $CF_CONT_IMAGE
        ;;

    push-cf-image)
        check_run_as_root
        docker push $CF_CONT_IMAGE
        ;;

    up-prev-cf-image)
        check_run_as_root
        docker pull $CF_CONT_PREV_IMAGE
        docker tag $CF_CONT_PREV_IMAGE $CF_CONT_IMAGE
        echo
        echo -n "Are you sure to push '$CF_CONT_IMAGE' image to docker hub? [y/n] "
        read -n 1 answ
        case $answ in
            y|Y) docker push $CF_CONT_IMAGE ;;
            *) echo; echo "OK, skipping the pushing ..." ;;
        esac
        ;;

    ### CF Image #### end ####

    
    ### Common Image ### begin ###

    pull-images)
        check_run_as_root
        docker pull $DB_CONT_IMAGE
        docker pull $CF_CONT_IMAGE
        docker pull $BF_CONT_IMAGE
        ;;

    pull-prev-images)
        check_run_as_root
        docker pull $DB_CONT_PREV_IMAGE
        docker pull $CF_CONT_PREV_IMAGE
        docker pull $BF_CONT_PREV_IMAGE
        ;;

    ### Common Image #### end ####


    ### Database ### begin ###

    create-dbs)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        create_dbs $num
        ;;

    db-shell)
        run_db_shell $2
        ;;

    db-query)
        do_db_query comn $2 $3
        ;;

    block-chain-count)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        block_chain_count $num
        ;;

    first-blocks)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        get_first_blocks $num
        ;;
        
    cmp-first-blocks)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        cmp_first_blocks $num
        ;;

    keys)
        [ -z "$2" ] && echo "Backend number isn't set" && exit 58
        do_db_query comn $2 "select \* from \"1_keys\" order by id;"
        ;;

    cmp-keys)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        cmp_keys $num
        ;;

    wait-keys)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        wait_keys_sync $num
        ;;

    ### Database #### end ####


    ### Backend ### begin ###

    touch-file)
        docker exec -ti $BF_CONT_NAME bash -c 'touch /BBBB'
        ;;

    rm-file)
        docker exec -ti $BF_CONT_NAME bash -c '[ -e /BBBB ] && rm /BBBB'
        ;;

    check-file)
        docker exec -ti $BF_CONT_NAME bash -c '[ -e /BBBB ] && echo "exists" || echo "does not exist"'
        ;;

    check-be-apps)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        check_backend_apps_status $num
        ;;

    be-apps-ctl)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 17
        backend_apps_ctl $num $2
        ;;

    http-priv-key)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 30
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 18
        get_http_priv_key "http://127.0.0.1:PORT/keys/PrivateKey" $2 200 64 $wps
        ;;

    priv-key)
        get_priv_key $2
        ;;

    priv-keys)
        get_priv_keys $2
        ;;

    setup-be-apps)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 19
        setup_be_apps $num
        ;;

    start-be-apps)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 19
        start_be_apps $num $cps
        ;;

    check-priv-key)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 32
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 19
        check_http_priv_key "http://127.0.0.1:PORT/keys/PrivateKey" $2 200 64 $wps
        ;;

    wait-priv-key)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 33
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 20
        wait_http_priv_key "http://127.0.0.1:PORT/keys/PrivateKey" $2 200 64 20 $wps
        ;;

    check-uid)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 33
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 21
        [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT
        c_port=$(expr $cps + $2)
        check_http_len http://127.0.0.1:$c_port/api/v2/getuid 200,201 100
        ;;

    uid)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 33
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 21
        [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT
        c_port=$(expr $cps + $2)
        get_http_len http://127.0.0.1:$c_port/api/v2/getuid 200,201 100
        ;;

    tail-be-log)
        tail_be_log $2
        ;;

    update-keys)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 21
        start_update_keys $num
        ;;

    update-full-nodes)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 21
        start_update_full_nodes $num
        ;;

    demo-page-url)
        get_demo_page_url_from_dockerfile
        ;;

    import-demo-apps)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 21
        start_import_demo_apps
        ;;

    demo-apps-ver)
        get_demo_apps_ver || exit 63
        ;;

    build-be)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 21
        build_be $num || exit 61
        ;;

    clean-be-build)
        clean_be_build || exit 61
        ;;

    be-ver|be-version)
        get_be_ver || exit 61
        ;;

    be-git-ver|be-git-version)
        get_be_git_ver || exit 61
        ;;

    mbs)
        shift 1
        run_mbs_cmd $@
        ;;

    ### Backend #### end ####


    ### Frontend ### begin ###

    setup-fe-apps)
        shift 1
        setup_fe_apps $@
        ;;

    start-fe-apps)
        shift 1
        start_fe_apps $@
        ;;

    build-fe)
        build_fe || exit 62
        ;;

    clean-fe-build)
        clean_fe_build || exit 62
        ;;

    fe-ver|fe-version)
        get_fe_ver || exit 63
        ;;

    fe-git-ver|fe-git-version)
        get_fe_git_ver || exit 63
        ;;

    ### Frontend #### end ####


    ### Main #### begin ###

    install)
        check_run_as_root
        check_num_param $2
        start_docker
        check_host_ports $2 $3 $4 $5
        [ $? -ne 0 ] \
            && echo "Please free busy ports first or customize ports shifts" \
            && exit 100
        echo
        save_install_params $2 $3 $4 $5
        start_install $2 $3 $4 $5
        ;;

    set-params)
        echo "Saving install parameters ..."
        check_num_param $2
        save_install_params $2 $3 $4 $5
        ;;

    del-params)
        echo "Removing install parameters ..."
        clear_install_params
        ;;

    params)
        show_install_params
        ;;

    reinstall)
        check_run_as_root
        params="$(read_install_params)"
        [ -z "$params" ] \
            && echo "No install parameters found. Please start install first" \
            && exit 50
        delete_install
        start_install $(read_install_params) 
        ;;

    stop)
        check_run_as_root
        stop_all
        ;;

    start)
        check_run_as_root
        start_all
        ;;

    status)
        check_run_as_root
        show_status
        ;;

    build-images)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $DB_CONT_NAME -f $DB_CONT_BUILD_DIR/Dockerfile $DB_CONT_BUILD_DIR/.)
        (cd "$SCRIPT_DIR" \
            && docker build -t $CF_CONT_NAME -f $CF_CONT_BUILD_DIR/Dockerfile $CF_CONT_BUILD_DIR/.)
        (cd "$SCRIPT_DIR" \
            && docker build -t $DB_CONT_NAME -f $DB_CONT_BUILD_DIR/Dockerfile $DB_CONT_BUILD_DIR/.)
        ;;

    delete)
        check_run_as_root
        delete_install
        clear_install_params
        ;;

    images)
        show_docker_images
        ;;

    prev-images)
        show_prev_docker_images
        ;;

    all-images)

        show_all_docker_images
        ;;


    delete-all)
        check_run_as_root
        stop_clients
        delete_install
        clear_install_params
        show_all_docker_images | while read line; do
            image_id="$(echo "$line" | awk '{print $1}')"
            docker rmi -f $image_id
        done
        #docker rmi -f $BF_CONT_IMAGE
        #docker rmi -f $CF_CONT_IMAGE
        #docker rmi -f $DB_CONT_IMAGE
        ;;

    version)
        echo "$VERSION"
        ;;

    versions)
        echo "Quick Start version: $VERSION"
        echo
        echo "Backend version: "
        get_be_git_ver
        echo
        echo "Frontend version: "
        get_fe_git_ver
        echo
        echo "Golang version: $GOLANG_VER"
        echo
        echo "Demo apps URL: $GENESIS_DEMO_APPS_URL"
        echo
        ;;

    *)
        show_usage_help
        ;;
esac

### Run #### end ####
