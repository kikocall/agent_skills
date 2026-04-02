#!/usr/bin/env bash

set -o pipefail

tdh_is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

tdh_return_or_exit() {
    local status="${1:-0}"
    if tdh_is_sourced; then
        return "${status}"
    fi
    exit "${status}"
}

tdh_log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "${level}" "$*"
}

tdh_info() { tdh_log INFO "$@"; }
tdh_warn() { tdh_log WARN "$@" >&2; }
tdh_error() { tdh_log ERROR "$@" >&2; }

tdh_require_command() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1 || {
        tdh_error "缺少命令: ${cmd}"
        return 1
    }
}

tdh_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

tdh_iso_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

tdh_state_root() {
    printf '%s\n' "${TDH_STATE_ROOT:-$HOME/.codex/tdh-cluster}"
}

tdh_runtime_root() {
    printf '%s/runtime\n' "$(tdh_results_root)"
}

tdh_results_root() {
    printf '%s\n" "${TDH_RESULTS_ROOT:-$HOME/tdh-test-results}"
}

tdh_client_home() {
    local candidates=()
    if [ -n "${TDH_CLIENT_HOME:-}" ]; then
        candidates+=("${TDH_CLIENT_HOME}")
    fi
    if [ -n "${TDH_CLIENT:-}" ]; then
        candidates+=("${TDH_CLIENT}")
    fi
    candidates+=(
        "$HOME/TDH-Client"
        "$HOME/tdh-client/TDH-Client"
        "/opt/TDH-Client"
        "./TDH-Client"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [ -d "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

tdh_require_client_home() {
    TDH_CLIENT_HOME="$(tdh_client_home)" || {
        tdh_error "未找到 TDH-Client 目录，请讲置 TDH_CLIENT_HOME"
        return 1
    }
    export TDH_CLIENT_HOME
}

tdh_resolve_path() {
    local path="$1"
    if [ -L "${path}" ]; then
        local target
        target="$(readlink "${path}")"
        case "${target}" in
            /)*) printf '%s\n' "${target}" ;;
            *) printf '%s\n' "$(cd "$(dirname "${path}")" && cd "$(dirname "${target}")" && pwd)/$(basename "${target}")" ;;
        esac
        return 0
    fi
    printf '%s\n' "${path}"
}

tdh_basename() {
    basename "$1"
}

tdh_normalize_name() {
    local name
    name="$(basename "$1" | tr '[:upper:]' '[:lower:]')"
    name="$(printf '%s' "${name}" | sed -E 's/(^|[-_])(conf|config|configuration|kerberos|krb)([-_]|$)/-/g; s/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
    printf '%s\n' "${name}"
}

tdh_is_conf_candidate() {
    local dir="$1"
    find "${dir}" -maxdepth 2 -type f \( \
        -name 'core-site.xml' -o \
        -name 'hdfs-site.xml' -o \
        -name 'yarn-site.xml' -o \
        -name 'hbase-site.xml' -o \
        -name 'hive-site.xml' -o \
        -name 'server.properties' \
    \) | grep -q .
}

tdh_is_kerberos_candidate() {
    local dir="$1"
    find "${dir}" -maxdepth 2 -type f \( \
        -name 'krb5.conf' -o \
        -name '*.keytab' -o \
        -name 'jaas.conf' \
    \) | grep -q .
}

tdh_collect_conf_dirs() {
    tdh_require_client_home || return 1
    local dir
    for dir in "${TDH_CLIENT_HOME}"/*; do
        [ -d "${dir}" ] || continue
        case "$(basename "${dir}")" in
            conf|kerberos|hadoop|inceptor|kafka|zookeeper|hyperbase|impexp|sqoop|bin|lib)
                continue
                ;;
        esac
        if tdh_is_conf_candidate "${dir}"; then
            printf '%s\n' "${dir}"
        fi
    done
}

tdh_collect_kerberos_dirs() {
    tdh_require_client_home || return 1
    local dir
    for dir in "${TDH_CLIENT_HOME}"/*; do
        [ -d "${dir}" ] || continue
        case "$(basename "${dir}")" in
            conf|kerberos|hadoop|inceptor|kafka|zookeeper|hyperbase|impexp|sqoop|bin|lib)
                continue
                ;;
        esac
        if tdh_is_kerberos_candidate "${dir}"; then
            printf '%s\n' "${dir}"
        fi
    done
}

tdh_active_conf_dir() {
    tdh_require_client_home || return 1
    [ -e "${TDH_CLIENT_HOME}/conf" ] || return 1
    tdh_resolve_path "${TDH_CLIENT_HOME}/conf"
}

tdh_active_kerberos_dir() {
    tdh_require_client_home || return 1
    [ -e "${TDH_CLIENT_HOME}/kerberos" ] || return 1
    tdh_resolve_path "${TDH_CLIENT_HOME}/kerberos"
}

tdh_extract_xml_property() {
    local search_dir="$1"
    local property_name="$2"
    local file_glob="$3"

    python - "$search_dir" "$property_name" "$file_glob" <<'PY'
import os
import sys
import glob
import xml.etree.ElementTree as ET

root_dir, property_name, file_glob = sys.argv[1:]
paths = glob.glob(os.path.join(root_dir, "**", file_glob), recursive=True)
for path in paths:
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    for prop in tree.findall(".//property"):
        name = prop.findtext("name", default="").strip()
        if name == property_name:
            value = prop.findtext("value", default="").strip()
            if value:
                print(value)
                raise SystemExit(0)
raise SystemExit(1)
PY
}
