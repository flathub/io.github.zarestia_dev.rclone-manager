#!/bin/bash

# Based on: https://github.com/flathub/org.gnome.Builder/blob/master/fusermount-wrapper.sh

FD_ARGS=()

# Forward file descriptors for FUSE communication
if [ -n "$_FUSE_COMMFD" ]; then
    FD_ARGS+=("--env=_FUSE_COMMFD=${_FUSE_COMMFD}")
    if [ "$_FUSE_COMMFD" != "0" ] && [ "$_FUSE_COMMFD" != "1" ] && [ "$_FUSE_COMMFD" != "2" ]; then
        FD_ARGS+=("--forward-fd=${_FUSE_COMMFD}")
    fi
fi

# Forward /dev/fuse file descriptor if passed
for ARG in "$@"; do
    if [[ "$ARG" =~ ^/dev/fd/[0-9]+$ ]]; then
        FD="${ARG#/dev/fd/}"
        FD_ARGS+=("--forward-fd=${FD}")
    fi
done

exec flatpak-spawn --host "${FD_ARGS[@]}" fusermount3 "$@"