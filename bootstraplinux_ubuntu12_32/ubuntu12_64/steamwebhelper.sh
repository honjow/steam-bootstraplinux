#!/bin/bash

# verbose
#set -x

set -eu

DIR="$(dirname "$0")"
cd "${DIR}"
# Make it an absolute path
DIR="$(pwd)"

# Steam client sets this to help us locate steamrt SLR
STEAM_BASE_FOLDER="${STEAM_BASE_FOLDER:-$(realpath -e ~/.steam/steam || echo ~/.local/share/Steam)}"

BASENAME="$(basename "$0")"
log () {
    ( echo "${BASENAME}[$$]: $*" >&2 ) || :
}

: "${STEAM_RUNTIME_SCOUT:="$HOME/.steam/root/ubuntu12_32/steam-runtime"}"

if ! source "${STEAM_RUNTIME_SCOUT}/usr/libexec/steam-runtime-tools-0/logger-0.bash" \
    --filename=webhelper-linux.txt \
    --identifier=steamwebhelper \
    --parse-level-prefix \
    ${STEAMWEBHELPER_USE_TERMINAL:+--terminal-level=debug} \
    --journal-level=info \
; then
    log "Couldn't set up logger, continuing to use inherited fd"
fi

# Disable interactive shell wrappers, etc.
export PRESSURE_VESSEL_BATCH=1
# Always share home directory with steamwebhelper: it is conceptually part
# of Steam, so even if we are redirecting each game to its own fake home
# directory, we want steamwebhelper and Steam to agree on what $HOME is
export PRESSURE_VESSEL_SHARE_HOME=1

if test -f "/etc/ca-certificates/trust-source/anchors/constraind-valve-ca.cer"; then
    # Enabling testing against dev stores (Valve internal)
    log "Enabling import of external CAs into pressure-vessel runtime"
    export PRESSURE_VESSEL_IMPORT_CA_CERTS=1
fi

# Configure the runtime to add the current working directory to the search path
# FIXME: only works for LDLP runtimes (heavy, now retired) and not SLR
export STEAM_COMPAT_FLAGS=search-cwd,search-cwd-first
export STEAM_COMPAT_INSTALL_PATH="${DIR}"

entry_point=

: "${STEAM_RUNTIME_STEAMRT:="$(realpath "${DIR}/../steamrt64/steam-runtime-steamrt")"}"
entry_point="${STEAM_RUNTIME_STEAMRT}/_v2-entry-point"
log "Starting steamwebhelper under bootstrap steamrt steam runtime via: ${entry_point}"

# Supports launching from the steamrt SLR steam depot or some locally provided directory
# Useful to keep around, even though the bootstrap launch path above should take care of everything
if [ ! -x "$entry_point" ]; then
    # Too many gotchas around zenity, don't try to use it directly :laughcry:
    ../steam_msg.sh --error "steamwebhelper requires the steamrt steam runtime.\n\nNot found at ${STEAM_RUNTIME_STEAMRT}, there is a problem with your installation, aborting."
    exit 1
fi

case " $* " in
    (*\ --no-sandbox\ *)
        log "CEF sandbox already disabled"
        ;;

    (*)
        can_sandbox=yes

        if [ -r /proc/sys/kernel/unprivileged_userns_clone ] && [ "$(< /proc/sys/kernel/unprivileged_userns_clone)" = 0 ]; then
            # https://github.com/ValveSoftware/steam-for-linux/issues/8373, part 2
            # (version seen on Debian 10, SteamOS 2, Arch linux-hardened, etc.)
            log "kernel.unprivileged_userns_clone=0, disabling sandbox"
            can_sandbox=
        fi

        if [ -r /proc/sys/user/max_user_namespaces ] && [ "$(< /proc/sys/user/max_user_namespaces)" = 0 ]; then
            # https://github.com/ValveSoftware/steam-for-linux/issues/8373, part 2
            # (version seen on RHEL 7, etc.)
            log "user.max_user_namespaces=0, disabling sandbox"
            can_sandbox=
        fi

        if [ -e /.flatpak-info ]; then
            # https://github.com/ValveSoftware/steam-for-linux/issues/8373, part 3
            log "Running under Flatpak, disabling sandbox"
            can_sandbox=
        fi

        if [ "$can_sandbox" = "without-seccomp" ]; then
            set -- --disable-seccomp-filter-sandbox "$@"
        elif [ -z "$can_sandbox" ]; then
            set -- --no-sandbox "$@"
        fi
        ;;
esac

log "Starting steamwebhelper with steamrt steam runtime at ${entry_point}"
exec \
    "${entry_point}" -- \
    "${DIR}/steamwebhelper_sniper_wrap.sh" "$@"
