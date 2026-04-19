#!/bin/bash
# Common helper functions and variables for all build scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default static prefix inside SDK container
PREFIX="${PREFIX:-/work/static-prefix}"
BUILDDIR="${BUILDDIR:-/work/build}"
ARIA2_SRC="${REPO_ROOT}/aria2-builder"
NPROC="$(nproc 2>/dev/null || echo 4)"

export PREFIX BUILDDIR ARIA2_SRC NPROC

log_info()  { echo "==> $*"; }
log_warn()  { echo "WARNING: $*" >&2; }
log_error() { echo "ERROR: $*" >&2; }
log_fatal() { log_error "$@"; exit 1; }

resolve_extra_libs() {
    local compiler="${1:?compiler required}"
    shift || true

    local item archive
    for item in "$@"; do
        case "$item" in
            -latomic)
                archive="$($compiler -print-file-name=libatomic.a 2>/dev/null || true)"
                if [ -n "$archive" ] && [ "$archive" != "libatomic.a" ] && [ -f "$archive" ]; then
                    printf '%s\n' "$archive"
                else
                    printf '%s\n' "$item"
                fi
                ;;
            *)
                printf '%s\n' "$item"
                ;;
        esac
    done
}

ensure_dir() {
    mkdir -p "$@"
}

download_source() {
    local url="$1" dest="$2"
    if [ -f "$dest" ]; then
        log_info "Already downloaded: $dest"
        return 0
    fi
    log_info "Downloading $url"
    curl -L --retry 5 --connect-timeout 15 -o "$dest" "$url"
}

extract_source() {
    local archive="$1" dest_dir="$2"
    ensure_dir "$dest_dir"
    case "$archive" in
        *.tar.gz)  tar xf "$archive" -C "$dest_dir" ;;
        *.tar.bz2) tar xf "$archive" -C "$dest_dir" ;;
        *.tar.xz)  tar xf "$archive" -C "$dest_dir" ;;
        *) log_fatal "Unknown archive format: $archive" ;;
    esac
}

get_aria2_version() {
    local ver
    ver=$(grep '^AC_INIT' "$ARIA2_SRC/configure.ac" | sed -n 's/.*\[\([0-9][0-9.]*\)\].*/\1/p')
    if [ -z "$ver" ]; then
        ver="unknown"
    fi
    echo "$ver"
}

get_submodule_commit() {
    git -C "$REPO_ROOT" rev-parse HEAD:aria2-builder 2>/dev/null || echo "unknown"
}
