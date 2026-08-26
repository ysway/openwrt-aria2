#!/bin/bash
# Reconcile the local OpenWrt dependency policy with an aria2-next release.
#
# Upstream's dependencies.env belongs to an external submodule. It is parsed as
# data and never sourced. Downloaded dependencies must retain a manually
# reviewed version/archive/URL/SHA-256 tuple; version-only updates are rejected.
# Vendored dependency labels may be updated automatically because their source
# is already fixed by the selected submodule gitlink.

set -euo pipefail

UPSTREAM_DEPS="${1:?Usage: sync_dependency_manifest.sh <upstream-dependencies.env> <local-versions.sh>}"
TARGET_FILE="${2:?Local versions file required}"

fatal() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$UPSTREAM_DEPS" ] || fatal "Missing upstream dependency file: $UPSTREAM_DEPS"
[ -f "$TARGET_FILE" ] || fatal "Missing local dependency file: $TARGET_FILE"

declare -A upstream_versions=()
while IFS= read -r dependency_line || [ -n "$dependency_line" ]; do
    if [[ "$dependency_line" =~ ^[[:space:]]*$ ]] || \
       [[ "$dependency_line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    if [[ "$dependency_line" =~ ^([A-Z][A-Z0-9_]*_VERSION)=([0-9A-Za-z][0-9A-Za-z._+-]*)$ ]]; then
        version_var="${BASH_REMATCH[1]}"
        version_value="${BASH_REMATCH[2]}"
        if [ "${upstream_versions[$version_var]+defined}" = "defined" ]; then
            fatal "Duplicate upstream version assignment: $version_var"
        fi
        upstream_versions["$version_var"]="$version_value"
    elif [[ "$dependency_line" =~ ^[A-Z][A-Z0-9_]*_VERSION= ]]; then
        fatal "Invalid upstream version assignment: $dependency_line"
    elif [[ "$dependency_line" =~ ^[A-Z][A-Z0-9_]*= ]]; then
        # Archive, URL, and checksum fields are not trusted version inputs.
        continue
    else
        fatal "Unexpected syntax in $UPSTREAM_DEPS: $dependency_line"
    fi
done < "$UPSTREAM_DEPS"

# This file is owned by the current repository and defines the policy arrays.
# shellcheck source=/dev/null
. "$TARGET_FILE"

for manifest_name in \
    DOWNLOADED_VERSION_VARS \
    VENDORED_VERSION_VARS \
    IGNORED_UPSTREAM_VERSION_VARS; do
    declare -p "$manifest_name" >/dev/null 2>&1 || \
        fatal "Missing dependency policy array: $manifest_name"
done

declare -A policy_category=()
record_policy() {
    local category="$1"
    shift
    local version_var
    for version_var in "$@"; do
        [[ "$version_var" =~ ^[A-Z][A-Z0-9_]*_VERSION$ ]] || \
            fatal "Invalid dependency policy field: $version_var"
        if [ -n "${policy_category[$version_var]:-}" ]; then
            fatal "Dependency appears in multiple policy arrays: $version_var"
        fi
        policy_category["$version_var"]="$category"
    done
}

record_policy downloaded "${DOWNLOADED_VERSION_VARS[@]}"
record_policy vendored "${VENDORED_VERSION_VARS[@]}"
record_policy ignored "${IGNORED_UPSTREAM_VERSION_VARS[@]}"

# An unknown version field may represent a new dependency in the release build.
# Require an explicit classification instead of silently omitting it.
for version_var in "${!upstream_versions[@]}"; do
    if [ -z "${policy_category[$version_var]:-}" ]; then
        fatal "Unclassified upstream dependency: $version_var; review the build graph and classify it in $TARGET_FILE"
    fi
done

# Removing any classified field changes the upstream manifest contract. Keep it
# explicit until this repository is deliberately adapted to the new baseline.
for version_var in "${!policy_category[@]}"; do
    if [ -z "${upstream_versions[$version_var]:-}" ]; then
        fatal "Classified dependency removed upstream: $version_var; review the build graph before updating $TARGET_FILE"
    fi
done

validate_download_metadata() {
    local version_var="$1"
    local dependency_prefix="${version_var%_VERSION}"
    local archive_var="${dependency_prefix}_ARCHIVE"
    local url_var="${dependency_prefix}_URL"
    local sha_var="${dependency_prefix}_SHA256"
    local local_version="${!version_var:-}"
    local archive="${!archive_var:-}"
    local url="${!url_var:-}"
    local sha256="${!sha_var:-}"
    local url_path

    [ -n "$local_version" ] || fatal "Missing local assignment for $version_var"
    [ -n "$archive" ] || fatal "Missing downloaded dependency metadata: $archive_var"
    [ -n "$url" ] || fatal "Missing downloaded dependency metadata: $url_var"
    [ -n "$sha256" ] || fatal "Missing downloaded dependency metadata: $sha_var"
    [[ "$url" == https://* ]] || fatal "Downloaded dependency URL must use HTTPS: $url_var"
    [[ "$sha256" =~ ^[0-9a-f]{64}$ ]] || fatal "Invalid SHA-256 metadata: $sha_var"

    url_path="${url%%[?#]*}"
    [[ "$url_path" == */"$archive" ]] || \
        fatal "$url_var must end with the archive named by $archive_var"

    if [ "$version_var" = "SQLITE_VERSION" ]; then
        local sqlite_major sqlite_minor sqlite_patch sqlite_revision sqlite_extra
        local expected_autoconf
        IFS=. read -r \
            sqlite_major sqlite_minor sqlite_patch sqlite_revision sqlite_extra \
            <<< "$local_version"
        sqlite_revision="${sqlite_revision:-0}"
        if ! [[ "$sqlite_major" =~ ^[0-9]+$ && \
                "$sqlite_minor" =~ ^[0-9]+$ && \
                "$sqlite_patch" =~ ^[0-9]+$ && \
                "$sqlite_revision" =~ ^[0-9]+$ && \
                -z "$sqlite_extra" ]]; then
            fatal "Invalid SQLite release version: $local_version"
        fi
        expected_autoconf=$((
            10#$sqlite_major * 1000000 +
            10#$sqlite_minor * 10000 +
            10#$sqlite_patch * 100 +
            10#$sqlite_revision
        ))
        [ "${SQLITE_AUTOCONF_VERSION:-}" = "$expected_autoconf" ] || \
            fatal "SQLITE_AUTOCONF_VERSION does not match SQLITE_VERSION"
        [[ "$archive" == *"$SQLITE_AUTOCONF_VERSION"* ]] || \
            fatal "SQLITE_ARCHIVE does not match SQLITE_AUTOCONF_VERSION"
        [[ "${SQLITE_YEAR:-}" =~ ^[0-9]{4}$ && \
            "$url" == *"/${SQLITE_YEAR}/"* ]] || \
            fatal "SQLITE_URL does not match SQLITE_YEAR"
    else
        [[ "$archive" == *"$local_version"* ]] || \
            fatal "$archive_var does not identify $version_var=$local_version"
    fi

    if [ "$version_var" = "EXPAT_VERSION" ]; then
        [ "${EXPAT_TAG:-}" = "R_${local_version//./_}" ] || \
            fatal "EXPAT_TAG does not match EXPAT_VERSION"
        [[ "$url" == *"/${EXPAT_TAG}/"* ]] || \
            fatal "EXPAT_URL does not match EXPAT_TAG"
    elif [ "$version_var" = "OPENSSL_VERSION" ]; then
        [ "${OPENSSL_SERIES:-}" = "${local_version%.*}" ] || \
            fatal "OPENSSL_SERIES does not match OPENSSL_VERSION"
    fi
}

for version_var in "${DOWNLOADED_VERSION_VARS[@]}"; do
    validate_download_metadata "$version_var"
    local_version="${!version_var:-}"
    upstream_version="${upstream_versions[$version_var]}"
    if [ "$local_version" != "$upstream_version" ]; then
        echo "ERROR: Downloaded dependency version changed: $version_var" >&2
        echo "  upstream: $upstream_version" >&2
        echo "  local:    ${local_version:-<missing>}" >&2
        fatal "Update the version and its reviewed archive/URL/SHA-256 metadata in $TARGET_FILE"
    fi
done

for version_var in "${VENDORED_VERSION_VARS[@]}"; do
    if ! grep -q "^${version_var}=" "$TARGET_FILE"; then
        fatal "Missing local assignment for $version_var"
    fi

    local_version="${!version_var:-}"
    upstream_version="${upstream_versions[$version_var]}"
    if [ "$local_version" != "$upstream_version" ]; then
        sed -i "s|^${version_var}=.*|${version_var}=\"${upstream_version}\"|" "$TARGET_FILE"
        echo "Updated vendored dependency label: $version_var=$upstream_version"
    fi
done

echo "Synchronized vendored versions and verified downloaded dependency pins"
