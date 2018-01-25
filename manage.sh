#! /usr/bin/env bash

### Configuration ### begin ###

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

DOCKER_DMG_DL_URL="https://download.docker.com/mac/stable/Docker.dmg"
DOCKER_APP_DIR_SIZE_M=1126 # to update run 'du -sm /Applications/Docker.app'

APLA_CLIENT_DMG_DL_URL="https://github.com/AplaProject/apla-front/releases/download/v0.3.5/Apla-0.3.5.dmg"
APLA_CLIENT_APP_DIR_SIZE_M=227 # to update run 'du -sm /Applications/Apla.app'
APLA_CLIENT_APPIMAGE_DL_URL="https://github.com/AplaProject/apla-front/releases/download/v0.3.5/apla-0.3.5-x86_64.AppImage"

SED_E="sed -E"

BF_CONT_NAME="genesis-bf"
BF_CONT_IMAGE="str16071985/genesis-bf"
BF_CONT_BUILD_DIR="genesis-bf"
TRY_LOCAL_BF_CONT_NAME_ON_RUN="yes"

DB_CONT_NAME="genesis-db"
DB_CONT_IMAGE="str16071985/genesis-db"
DB_CONT_BUILD_DIR="genesis-db"
TRY_LOCAL_DB_CONT_NAME_ON_RUN="yes"

CF_CONT_NAME="genesis-cf"
CF_CONT_IMAGE="str16071985/genesis-cf"
CF_CONT_BUILD_DIR="genesis-cf"
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
    lsof -i :$1 | awk '{print $1}' | tail -n +2
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
    [ ! -d "$1" ] || du -sm "$1" | awk '{print $1}'
}

download_and_check_dmg() {
    local dmg_url; dmg_url="$1"
    local dmg_basename; dmg_basename="$(basename "$dmg_url")"
    (
        update_global_downloads_and_apps_dir_vars

        local dmg_path; dmg_path="$DOWNLOADS_DIR/$dmg_basename"
        echo "dmg_path: $dmg_path"
        [ -f "$dmg_path" ] \
            && mv "$dmg_path" "$dmg_path.bak.$(date "+%Y%m%d%H%M%S")"
        create_downloads_dir \
            && echo "Downloading $app_name ..." \
            && curl -L -o "$dmg_path" "$dmg_url"
    )
}

download_and_install_dmg() {
    local app_bin; app_bin="$1"
    local app_dir; app_dir="$2"
    local dmg_url; dmg_url="$3"
    local dmg_basename; dmg_basename="$4"
    local app_name; app_name="$5"
    local exp_size_m; exp_size_m=$6

    local timeout_secs; timeout_secs="180"

    local result; result=0

    if [ ! -f "$app_bin" ]; then
        (
            update_global_downloads_and_apps_dir_vars

            local dmg_path; dmg_path="$DOWNLOADS_DIR/$dmg_basename"
            if [ ! -f "$dmg_path" ]; then
                create_downloads_dir \
                    && echo "Downloading $app_name ..." \
                    && curl -L -o "$dmg_path" "$dmg_url" && open "$dmg_path" \
                    || result=1
            else
                open "$dmg_path"
            fi
        )
        while [ ! -f "$app_bin" ]; do
            echo "Please move $app_name to Applications"
            sleep 1
        done

        echo "$app_name is copying to Applications. Please wait (timeout: $timeout_secs seconds) ..."
        local end_time; end_time=$(( $(date +%s) + timeout_secs ))
        local stop; stop=0
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
                result=11
                ;;
            3)
                echo "$app_name probably installed (there was a timeout)"
                result=12
                ;;
        esac
    fi
    return $result
}

install_mac_docker_directly() {
    download_and_install_dmg "/Applications/Docker.app/Contents/MacOS/Docker" "/Applications/Docker.app" "$DOCKER_DMG_DL_URL" "$(basename "$DOCKER_DMG_DL_URL")" "Docker" $DOCKER_APP_DIR_SIZE_M
}

uninstall_mac_docker() {
    if [ "${USER}" != "root" ]; then
        echo "Please run this command with sudo or as root"
    	return 2
    fi

    if [ -e /Applications/Docker.app/Contents/MacOS/Docker ]; then
        /Applications/Docker.app/Contents/MacOS/Docker --uninstall
    fi
    
    if [ -n "$(command -v  docker-machine)" ]; then
        while true; do
            read -p "Remove all Docker Machine VMs? (Y/N): " yn
            case $yn in
                [Yy]* ) docker-machine rm -f $(docker-machine ls -q); break ;;
                [Nn]* ) break ;;
                * ) echo "Please answer yes or no."; exit 1;;
            esac
        done
    fi
    
    echo "Removing Docker from Applications..."
    [ -e /Applications/Docker.app ] \
        && rm -rf /Applications/Docker.app
    
    echo "Removing docker binaries..."
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

    echo "Docker completely removed"
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
    open -n /Applications/Docker.app
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

install_mac_apla_client_directly() {
    download_and_install_dmg "/Applications/Apla.app/Contents/MacOS/Apla" "/Applications/Apla.app" "$APLA_CLIENT_DMG_DL_URL" "$(basename "$APLA_CLIENT_DMG_DL_URL")" "Apla" $APLA_CLIENT_APP_DIR_SIZE_M
}

install_linux_apla_client_directly() {
    (
        update_global_downloads_and_apps_dir_vars
        local app_base; app_base="$(basename "$APLA_CLIENT_APPIMAGE_DL_URL")"
        local app_dl_path; app_dl_path="$DOWNLOADS_DIR/$app_base"
        local app_inst_path; app_inst_path="$APPS_DIR/$app_base"

        if [ ! -f "$app_inst_path" ]; then
            if [ ! -f "$app_dl_path" ]; then
                create_downloads_dir \
                    && echo "Downloading Apla Client ..." \
                    && run_as_orig_user "curl -L -o '$app_dl_path' '$APLA_CLIENT_APPIMAGE_DL_URL'"
            fi
            create_apps_dir \
                && mv "$app_dl_path" "$app_inst_path" \
                && chmod +x "$app_inst_path"
        fi
    )
}

### Download/install #### end ####


### Client ### begin ###

start_mac_clients() {
    local num; num=$1;
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of clients is not set" \
        && return 200
    local wps; wps=$2; [ -z "$wps" ] && wps=$WEB_PORT_SHIFT
    local cps; cps=$3; [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT

    install_mac_apla_client_directly

    local w_port; local c_port; local run_cmd
    for i in $(seq 1 $num); do
        w_port=$(expr $i + $wps)
        c_port=$(expr $i + $cps)
        echo "Starting client $i (web port: $w_port; client port: $c_port) ..."
        run_cmd="open -n /Applications/Apla.app/ --args API_URL=http://127.0.0.1:$c_port/api/v2 PRIVATE_KEY=http://127.0.0.1:$w_port/keys/PrivateKey"
        eval "$run_cmd"
    done
}

start_linux_clients() {
    local num; num=$1;
    ([ -z "$num" ] || [ $num -lt 1 ]) \
        && echo "The number of clients is not set" \
        && return 200
    local wps; wps=$2; [ -z "$wps" ] && wps=$WEB_PORT_SHIFT
    local cps; cps=$3; [ -z "$cps" ] && cps=$CLIENT_PORT_SHIFT

    install_linux_apla_client_directly

    (
        update_global_downloads_and_apps_dir_vars

        local app_base; app_base="$(basename "$APLA_CLIENT_APPIMAGE_DL_URL")"
        local app_inst_path; app_inst_path="$APPS_DIR/$app_base"

        local w_port; local c_port; local run_cmd
        for i in $(seq 1 $num); do
            w_port=$(expr $i + $wps)
            c_port=$(expr $i + $cps)
            echo "Starting client $i (web port: $w_port; client port: $c_port) ..."
            run_cmd="$app_inst_path API_URL=http://127.0.0.1:$c_port/api/v2 PRIVATE_KEY=http://127.0.0.1:$w_port/keys/PrivateKey &"
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
        pids=$(pgrep -f "Apla API_URL")
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
        pids=$(pgrep -f "apla API_URL")
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
    local id; id=$(check_cont "$1")
    case $? in
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
}

cont_exec() {
    local name; name="$1"
    local id; id=$(check_cont "$name"); [ $? -ne 0 ] && return 1
    shift 1
    local run_cmd; run_cmd="docker exec -ti $id $@"
    eval "$run_cmd"
}

prep_cont_for_inspect() {
    #cont_exec $1 "bash -c \"apt update --fix-missing; apt install -y tmux telnet net-tools vim nano links\""
    cont_exec $1 "bash -c 'apt update --fix-missing; apt install -y tmux telnet net-tools vim nano links'"
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
            docker run -d --restart always --name $BF_CONT_NAME $w_ports $c_ports -v apla:/s --link $DB_CONT_NAME:$DB_CONT_NAME --link $CF_CONT_NAME:$CF_CONT_NAME -t $image_name
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
    #local db; db=$(docker exec -t $DB_CONT_NAME bash -c "sudo -u postgres psql -lqt")
    #db=$(echo "$db" | $SED_E -n "s/^[^e]*($db_name)[^|]+.*$/\1/gp")
    local db; db=$(docker exec -t $DB_CONT_NAME bash -c "sudo -u postgres psql -lqt" | $SED_E -n "s/^[^e]*($db_name)[^|]+.*$/\1/gp")
    [ -z "$db" ] && echo "DB '$db_name' doesn't exist" && return 3
    echo "ok"
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
    return $result
}

check_dbs() {
    local num; num=$1
    echo "Checking databases for $num backends ..."
    local total_result; total_result=0; local result
    for i in $(seq 1 $num); do
        echo -n "  checking database for backend $i: "
        check_db_exists "eg$i"; result=$?
        [ $result -ne 0 ] && total_result=$result || echo "ok"
    done
    return $total_result
}

wait_dbs() {
    local num; num=$1
    local timeout_secs; [ -z "$2" ] && timeout_secs=15 || timeout_secs="$2"
    echo "Waiting ($timeout_secs seconds for each) databases for $num backends ..."
    local total_result; total_result=0; local result
    for i in $(seq 1 $num); do
        echo "  checking database for backend $i: "
        wait_db_exists "eg$i" $timeout_secs; result=$?
        [ $result -ne 0 ] && total_result=$result || echo "ok"
    done
    return $total_result
}

create_dbs() {
    local num; num=$1
    local timeout_secs; timeout_secs=$2
    local max_tries; [ -z "$3" ] && max_tries=5 || max_tries=$3

    echo "Creating/checking databases for $num backends ..."
    local total_result; total_result=0; local result
    local cnt; local stop
    for i in $(seq 1 $num); do
        cnt=1; stop=0
        while [ $stop -eq 0 ]; do
            if [ $cnt -gt 1 ]; then
                #sleep 1
                #if [ $cnt -gt 4 ]; then
                #    wait_db_exists "eg$i" $timeout_secs; result=$?
                #else
                #    wait_db_exists "eg$i" $(expr $cnt \* 2); result=$?
                #fi

                wait_db_exists "eg$i" $timeout_secs; result=$?
            else
                echo "Quick checking database 'eg$i' existence ..."
                check_db_exists "eg$i"; result=$?
            fi
            case $result in
                0)
                    [ $cnt -gt 1 ] && echo "Database 'eg$i' exists" \
                        || echo "Database 'eg$i' already exists"
                    stop=1
                    ;;
                3)
                    echo "Creating 'eg$i' database ..."
                    docker exec -t $DB_CONT_NAME bash /db.sh create postgres "eg$i"
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
        || db_name="eg$1"
    check_db_exists "$db_name" || return 3
    docker exec -t $DB_CONT_NAME bash -c \
        "sudo -u postgres psql -U postgres -d $db_name"
}

do_db_query() {
    local db_name
    [ -z "$1" ] && echo "Backend's number isn't set" && return 1 \
        || db_name="eg$1"
    local query; query="$2"; [ -z "$query" ] \
        && echo "Query string isn't set" && return 2
    check_db_exists "$db_name" || return 3
    docker exec -t $DB_CONT_NAME bash -c \
        "sudo -u postgres psql -U postgres -d $db_name -c '$query'"
}

block_chain_count() {
    local num; num="$1"; local query
    for i in $(seq 1 $num); do
        query='SELECT COUNT(*) FROM block_chain'
        echo -n "eg$i: $query: "
        do_db_query "$i" "$query" | tail -n +4 | head -n +1 | $SED_E 's/^ +//'
    done
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
    local url; url="$(echo "$1" | sed -E "s/:PORT/:$port/g")"
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
    wait_cont_http_code $CF_CONT_NAME http://127.0.0.1:8000/connection/ 200 15
    [ $? -ne 0 ] && echo "  centrifugo isn't ready" \
        && result=1 \
        || echo "  centrifugo ready"
}


check_backend_apps_status() {
    local num; num=$1
    local app_name; local result; result=0
    echo "Checking backends ..."
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="go_apla" || app_name="go_apla$i"
        echo -n "  backend number $i status: "
        # TODO: use CONT_CLIENT_PORT_SHIFT here
        check_cont_http_len $BF_CONT_NAME http://127.0.0.1:700$i/api/v2/getuid 200,201 100 
    done
    [ $result -ne 0 ] && echo "go_apla backends arn't ready" && exit 200 \
        || echo "Backends ready"
}

wait_backend_apps_status() {
    local num; num=$1
    local app_name; local result; result=0
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="go_apla" || app_name="go_apla$i"
        # TODO: use CONT_CLIENT_PORT_SHIFT here
        wait_cont_http_len $BF_CONT_NAME http://127.0.0.1:700$i/api/v2/getuid 200,201 100 20
        [ $? -ne 0 ] && echo "  gp_apla backend number $i isn't ready" \
            && result=1 \
            || echo "  gp_apla backend number $i ready"
    done
    [ $result -ne 0 ] && echo "go_apla backends arn't ready" && exit 200 \
        || echo "Backends ready"
}

backend_apps_ctl() {
    local num; [ -z "$1" ] && echo "Number of backends isnt' set" && return 1 \
        || num=$1
    local cmd; [ -z "$2" ] && echo "Command isn't set" \
        && echo "Available commands: status, stop, start, restart" \
        && return 2 || cmd="$2"
    check_cont $BF_CONT_NAME > /dev/null || return 3
    local app_name; local result; result=0; local rcmd
    for i in $(seq 1 $num); do
        [ $i -eq 1 ] && app_name="go_apla" || app_name="go_apla$i"
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

start_be_apps() {
    local num; [ -z "$1" ] \
        && echo "The number of backends isn't set" && return 1 \
        || num=$1
    local cps; [ -z "$2" ] && cps=$CLIENT_PORT_SHIFT || cps=$2

    echo "Starting backend applications ..."
    docker exec -t $BF_CONT_NAME bash /start.sh $num
    docker exec -t $BF_CONT_NAME bash -c "supervisorctl update"

    docker exec -t $BF_CONT_NAME bash -c "supervisorctl start $app_name"
    wait_backend_apps_status $num || return 2
}

stop_be_apps() {
    [ -z "$1" ] && echo "The number of backends isn't set"  && return 1
    echo "Stopping backend applications ..."
    local app_name
    for i in $(seq 1 $1); do
        [ $i -eq 1 ] && app_name="go_apla" || app_name="go_apla$i"
        docker exec -t $BF_CONT_NAME bash -c "supervisorctl stop $app_name"
    done
}

start_fe_apps() {
    docker exec -t $BF_CONT_NAME /start3.sh $num $cps
    wait_frontend_apps_status $num || return 3
}

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
        #echo -n "       getuid: "
        #check_http_code http://127.0.0.1:$w_port 200,201 20
        #echo -n "       priv_key: "
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


### Backends services #### end ####


### Misc ### begin ###

check_num_param() {
    [ -z "$1" ] && echo "The number of clients/backends is not set" && exit 100
    [ $1 -gt 5 ] \
        && echo "The maximum number of clients/backends is 5" && exit 101
}

save_install_params() {
    (
        update_global_home_var
        run_as_orig_user "echo \"$@\" > \"$HOME/.apla_quick_start\""
    )
}

show_install_params() {
    (
        update_global_home_var
        if [ -e "$HOME/.apla_quick_start" ]; then
            cat "$HOME/.apla_quick_start"
        else
            echo "No install params saved"
        fi
    )
}

read_install_params() {
    (
        update_global_home_var
        [ -e "$HOME/.apla_quick_start" ] && cat "$HOME/.apla_quick_start"
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
    )
}

delete_install() {
    stop_clients
    remove_cont $BF_CONT_NAME
    remove_cont $CF_CONT_NAME
    remove_cont $DB_CONT_NAME
}

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

    wait_cont_proc $DB_CONT_NAME postgres 15
    [ $? -ne 0 ] \
        && echo "Postgres process isn't available" && return 10 \
        || echo "Postgres ready"

    wait_db_exists postgres 15
    [ $? -ne 0 ] \
        && echo "postgres database isn't available" && return 11 \
        || echo "postgres database ready"

    wait_db_exists template0 15
    [ $? -ne 0 ] \
        && echo "template0 database isn't available" && return 12 \
        || echo "template0 database ready"

    wait_db_exists template1 15
    [ $? -ne 0 ] \
        && echo "template1 database isn't available" && return 13 \
        || echo "template1 database ready"

    echo

    create_dbs $num 15
    [ $? -ne 0 ] \
        && echo "Backend databases creation failed" && return 14 \
        || echo "Backend databases creation compete"

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

    start_be_apps $num $cps
    [ $? -ne 0 ] \
        && echo "Backend applications arn't available" && return 23 \
        || echo "Backend applications ready"
    echo

    start_fe_apps $num $cps
    [ $? -ne 0 ] \
        && echo "Fronend applications arn't available" && return 24 \
        || echo "Fronend applications ready"
    echo

    echo "Starting 'fullnodes' ..."
    docker exec -t $BF_CONT_NAME bash /fullnodes.sh $num

    docker exec -t $BF_CONT_NAME bash -c '[ -e /upkeys.sh ]'
    if [ $? -eq 0 ]; then
        echo "Starting 'upkeys' ..."
        docker exec -t $BF_CONT_NAME bash /upkeys.sh $num
    fi

    check_host_side $num $wps $cps $dbp
    [ $? -ne 2 ] && sleep 2 && start_clients $num $wps $cps
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

    wait_db_exists postgres 15
    [ $? -ne 0 ] \
        && echo "postgres database isn't available" && return 11 \
        || echo "postgres database ready"

    wait_db_exists template0 15
    [ $? -ne 0 ] \
        && echo "template0 database isn't available" && return 12 \
        || echo "template0 database ready"

    wait_db_exists template1 15
    [ $? -ne 0 ] \
        && echo "template1 database isn't available" && return 13 \
        || echo "template1 database ready"

    echo

    #create_dbs $num 15
    #[ $? -ne 0 ] \
    #    && echo "Backend databases creation failed" && return 14 \
    #    || echo "Backend databases creation compete"

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
}

show_status() {
    local num
    local wps
    local cps
    local dbp

    read_install_params_to_vars || return 1

    echo
    echo -n "Dababase container status: "
    get_cont_status $DB_CONT_NAME
    echo -n "Centrifugo container status: "
    get_cont_status $CF_CONT_NAME
    echo -n "Backends/Frontends container status: "
    get_cont_status $BF_CONT_NAME
    echo

    check_centrifugo_status
    echo

    check_backend_apps_status $num
    echo

    check_frontend_apps_status $num
    echo

    check_host_side $num $wps $cps $dbp
}

show_usage_help() {
    echo
    echo "Usage: $(basename "$0") <command> <parameter>"
    echo
    echo "  Commands:"
    echo
    echo "  install NUM [WPS] [CPS] [DBP]"
    echo "    Install Docker, Apla Client, database and backend containers"
    echo "      NUM - number of clients/backends (mandatory)"
    echo "      WPS - web port shift (optional, default: $WEB_PORT_SHIFT)"
    echo "      CPS - client port shift (optional, default: $CLIENT_PORT_SHIFT)"
    echo "      DBP - database host port (optional, default: $DB_PORT)"
    echo "    Example:"
    echo "      $(basename "$0") install 3 8000 17000"
    echo "      will install Docker, Apla Client, start database container,"
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
    echo "    Stop clients and delete all Apla-related docker containers"
    echo
    echo "  delete-all"
    echo "    Stop clients and delete all Apla-related docker containers and images"
    echo
    echo "  uninstall-docker"
    echo "    Docker unintaller for macOS"
    echo
    echo "  build"
    echo "    Build all (database and backend/frontend) container images"
    echo
    echo "  build-bf"
    echo "    Build backend/frontend container image"
    echo
    echo "  build-db"
    echo "    Build database container image"
    echo
}

### Misc #### end ####


### Run ### begin ###

[ "$0" = "$BASH_SOURCE" ] && case $1 in

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
        echo "res: $?"
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

    download-apla)
        download_and_check_dmg "$APLA_CLIENT_DMG_DL_URL"
        echo "res: $?"
        ;;

    install-apla)
        check_run_as_root
        install_mac_apla_client_directly
        echo "res: $?"
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
        install_linux_apla_client_directly
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

    db-cont-bash)
        check_run_as_root
        cont_bash $DB_CONT_NAME
        ;;

    build-db)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $DB_CONT_NAME -f $DB_CONT_BUILD_DIR/Dockerfile $DB_CONT_BUILD_DIR/.)
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

    ### DB Container #### end ####


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

    bf-cont-bash)
        check_run_as_root
        cont_bash $BF_CONT_NAME
        ;;

    build-bf)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $BF_CONT_NAME -f $BF_CONT_BUILD_DIR/Dockerfile $BF_CONT_BUILD_DIR/.)
        ;;

    ### BF Container #### end ####


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

    cf-cont-bash)
        check_run_as_root
        cont_bash $CF_CONT_NAME
        ;;

    build-cf)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $CF_CONT_NAME -f $CF_CONT_BUILD_DIR/Dockerfile $CF_CONT_BUILD_DIR/.)
        ;;

    ### CF Container #### end ####


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
        do_db_query $2 $3
        ;;

    block-chain-count)
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 16
        block_chain_count $num
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

    priv-key)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 30
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 18
        get_http_priv_key "http://127.0.0.1:PORT/keys/PrivateKey" $2 200 64 $wps
        ;;

    check-priv-key)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 31
        num=""; wps=""; cps=""; dbp=""
        read_install_params_to_vars || exit 19
        check_http_priv_key "http://127.0.0.1:PORT/keys/PrivateKey" $2 200 64 $wps
        ;;

    wait-priv-key)
        [ -z "$2" ] \
            && echo "The index number of a backend isn't set" \
            && exit 32
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

    ### Backend #### end ####


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
        echo "Settings params ..."
        check_num_param $2
        save_install_params $2 $3 $4 $5
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

    build)
        check_run_as_root
        (cd "$SCRIPT_DIR" \
            && docker build -t $DB_CONT_NAME -f $DB_CONT_BUILD_DIR/Dockerfile $DB_CONT_BUILD_DIR/.)
        (cd "$SCRIPT_DIR" \
            && docker build -t $BF_CONT_NAME -f $BF_CONT_BUILD_DIR/Dockerfile $BF_CONT_BUILD_DIR/.)
        ;;

    delete)
        check_run_as_root
        delete_install
        clear_install_params
        ;;

    delete-all)
        check_run_as_root
        stop_clients
        delete_install
        clear_install_params
        docker rmi -f $BF_CONT_IMAGE
        docker rmi -f $CF_CONT_IMAGE
        docker rmi -f $DB_CONT_IMAGE
        ;;

    *)
        show_usage_help
        ;;
esac

### Run #### end ####
