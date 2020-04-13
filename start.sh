#!/usr/bin/env bash

# Version comparator (0 for same version, 1 for greater than, 2 for less than)
# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0

}

# Verify if used tools are present
check_needed_tools() {

    NEEDED_TOOLS="wget docker-compose"
    for tool in $NEEDED_TOOLS; do

        if ! [ -x "$(command -v $tool)" ]; then
            echo "Error: $tool is not installed." >&2
            exit 1
        fi

    done

}

# Verify docker and podman are up to date
check_docker_version() {

    if [ -x "$(command -v podman)" ]; then

        DOCKER="podman"
        DOCKER_VERSION=$(podman version --format '{{.Version}}' | cut -d"-" -f1)
        MIN_VERSION=1.5


    elif [ -x "$(command -v docker)" ]; then

        DOCKER="docker"
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' | cut -d"-" -f1)
        MIN_VERSION=18.0.0

    else
        echo "Error: you need to have either podman or docker installed." >&2
        exit 1
    fi

    vercomp $DOCKER_VERSION $MIN_VERSION
    if [ $? == 2 ]; then
        echo "Error: $DOCKER need to be at least in version $MIN_VERSION ($DOCKER_VERSION < $MIN_VERSION)." >&2
        exit 1
    fi

    DOCKER_COMPOSE_VERSION=$(docker-compose version --short)
    MIN_VERSION=1.24.0

    vercomp $DOCKER_COMPOSE_VERSION $MIN_VERSION
    if [ $? == 2 ]; then
        echo "Error: docker-compose need to be at least in version $MIN_VERSION ($DOCKER_COMPOSE_VERSION < $MIN_VERSION)." >&2
        exit 1
    fi

}

# Ensure just is installed
ensure_just() {

    if ! [ -x "$(command -v just)" ]; then
        # Install just
        wget -q -O- https://japaric.github.io/trust/install.sh | sh -s -- --git casey/just --target x86_64-unknown-linux-musl --to $JUST_FOLDER
    fi

}

JUSTFILE_LOCATION="https://raw.githubusercontent.com/AnotherMangos/core/master/Justfile"
JUST_FOLDER="/usr/bin"

if [ "$EUID" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

check_needed_tools
check_docker_version
ensure_just

# Fetch the Justfile
wget -q -O ./Justfile $JUSTFILE_LOCATION
