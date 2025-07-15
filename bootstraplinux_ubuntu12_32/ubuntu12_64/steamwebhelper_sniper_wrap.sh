#!/bin/bash

# mimic STEAM_COMPAT_FLAGS=search-cwd,search-cwd-first, which is currently not supported in SLR
export LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Avoid sending steamwebhelper output to terminal by telling srt-logger
# that all stdout/stderr is at debug level, but still send it to the
# log file and Journal
echo "<6>exec ./steamwebhelper $*"
echo "<remaining-lines-assume-level=7>"
# current gdbserver against steamwebhelper is not stable, do not use
# do pid attach across the container boundary instead
#exec /usr/bin/gdbserver 127.0.0.1:2345 ./steamwebhelper "$@"
exec ./steamwebhelper "$@"
