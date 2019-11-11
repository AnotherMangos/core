#!/usr/bin/env bash

# TODO change for the public Jusfile URL when this repository will be released
JUSTFILE_LOCATION="https://gist.githubusercontent.com/CedricThomas/f8d4d13726cd74726dfb4655748742cb/raw/05d1042158c3e9581f54745c3f103ef58adae8e8/Justfile"
JUST_FOLDER="/usr/bin"

if [ "$EUID" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Ensure just is installed
if ! [ -x "$(command -v just)" ]; then

    # Ensure curl is installed
    if ! [ -x "$(command -v curl)" ]; then
        echo 'Error: curl is not installed.' >&2
        exit 1
    fi

    # Install just
    curl -LSfs https://japaric.github.io/trust/install.sh | sh -s -- --git casey/just --target x86_64-unknown-linux-musl --to $JUST_FOLDER

fi

# Fetch the Justfile
curl -LSfs $JUSTFILE_LOCATION -o ./Justfile
