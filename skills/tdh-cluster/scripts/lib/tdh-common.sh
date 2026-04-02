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
    printf '%s/runtime\n' "$(tdh_state_root)"
}

tdh_results_root() {
    printf '%s\n' "${TDH_RESULTS_ROOT:-$HOME/tdh-test-results}"
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
        tdh_error "未找到 TDH-Client 目录，请设置 TDH_CLIENT_HOME"
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
            /*) printf '%s\n' "${target}" ;;
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

tdh_extract_xml_property_all() {
    local search_dir="$1"
    local property_name="$2"
    local file_glob="$3"

    python - "$search_dir" "$property_name" "$file_glob" <<'PY'
import os
import sys
import glob
import xml.etree.ElementTree as ET

root_dir, property_name, file_glob = sys.argv[1:]
paths = sorted(glob.glob(os.path.join(root_dir, "**", file_glob), recursive=True))
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
                print(f"{path}\t{value}")
PY
}

tdh_detect_realm_from_conf() {
    local conf_dir="$1"
    local principal
    principal="$(grep -RhoE '@[A-Z0-9._-]+' "${conf_dir}" 2>/dev/null | head -1 | sed 's/^@//')" || true
    if [ -n "${principal}" ]; then
        printf '%s\n' "${principal}"
        return 0
    fi
    return 1
}

tdh_detect_realm_from_kerberos_dir() {
    local kerberos_dir="$1"
    if [ -f "${kerberos_dir}/krb5.conf" ]; then
        awk '/default_realm/ {print $3; exit}' "${kerberos_dir}/krb5.conf"
        return 0
    fi
    return 1
}

tdh_map_auth_value() {
    local value="${1:-}"
    local default_mode="${2:-UNKNOWN}"
    value="$(printf '%s' "${value}" | tr '[:lower:]' '[:upper:]')"
    case "${value}" in
        KERBEROS)
            printf 'KERBEROS\n'
            ;;
        SIMPLE|NONE)
            printf 'SIMPLE_OR_NONE\n'
            ;;
        LDAP)
            printf 'LDAP_POSSIBLE\n'
            ;;
        '')
            printf '%s\n' "${default_mode}"
            ;;
        *)
            printf '%s\n' "${value}"
            ;;
    esac
}

tdh_detect_base_auth_mode() {
    local conf_dir="$1"
    local value
    value="$(tdh_extract_xml_property "${conf_dir}" 'hadoop.security.authentication' 'core-site.xml' 2>/dev/null || true)"
    tdh_map_auth_value "${value}" "SIMPLE_OR_NONE"
}

tdh_detect_hbase_auth_mode() {
    local conf_dir="$1"
    local value
    value="$(tdh_extract_xml_property "${conf_dir}" 'hbase.security.authentication' 'hbase-site.xml' 2>/dev/null || true)"
    tdh_map_auth_value "${value}" "UNKNOWN"
}

tdh_detect_quark_auth_mode() {
    local conf_dir="$1"
    local value
    value="$(tdh_extract_xml_property "${conf_dir}" 'hive.server2.authentication' 'hive-site.xml' 2>/dev/null || true)"
    tdh_map_auth_value "${value}" "UNKNOWN"
}

tdh_score_pairing() {
    local conf_dir="$1"
    local kerberos_dir="$2"
    local score=0
    local conf_name kerb_name conf_norm kerb_norm conf_realm kerb_realm
    conf_name="$(basename "${conf_dir}")"
    kerb_name="$(basename "${kerberos_dir}")"
    conf_norm="$(tdh_normalize_name "${conf_name}")"
    kerb_norm="$(tdh_normalize_name "${kerb_name}")"
    conf_realm="$(tdh_detect_realm_from_conf "${conf_dir}" 2>/dev/null || true)"
    kerb_realm="$(tdh_detect_realm_from_kerberos_dir "${kerberos_dir}" 2>/dev/null || true)"

    if [ "${conf_norm}" = "${kerb_norm}" ] && [ -n "${conf_norm}" ]; then
        score=$((score + 100))
    fi
    if [ -n "${conf_realm}" ] && [ "${conf_realm}" = "${kerb_realm}" ]; then
        score=$((score + 20))
    fi
    if [[ "${conf_name}" == "${kerb_name}"* || "${kerb_name}" == "${conf_name}"* ]]; then
        score=$((score + 10))
    fi
    printf '%s\n' "${score}"
}

tdh_pair_kerberos_dir() {
    local conf_dir="$1"
    local active_conf active_kerb
    active_conf="$(tdh_active_conf_dir 2>/dev/null || true)"
    active_kerb="$(tdh_active_kerberos_dir 2>/dev/null || true)"
    if [ -n "${active_conf}" ] && [ "${conf_dir}" = "${active_conf}" ] && [ -n "${active_kerb}" ]; then
        printf '%s|paired\n' "${active_kerb}"
        return 0
    fi

    local kerb_dir score best_score=-1 best_dir="" tie=0
    while IFS= read -r kerb_dir; do
        [ -n "${kerb_dir}" ] || continue
        score="$(tdh_score_pairing "${conf_dir}" "${kerb_dir}")"
        if [ "${score}" -gt "${best_score}" ]; then
            best_score="${score}"
            best_dir="${kerb_dir}"
            tie=0
        elif [ "${score}" -eq "${best_score}" ] && [ "${score}" -gt 0 ]; then
            tie=1
        fi
    done < <(tdh_collect_kerberos_dirs)

    if [ "${best_score}" -le 0 ]; then
        printf '|unpaired\n'
        return 0
    fi
    if [ "${tie}" -eq 1 ]; then
        printf '%s|ambiguous\n' "${best_dir}"
        return 0
    fi
    printf '%s|paired\n' "${best_dir}"
}

tdh_cluster_matches() {
    local requested="$1"
    local conf_dir="$2"
    local base
    base="$(basename "${conf_dir}")"
    [ "${requested}" = "${base}" ] || [ "${requested}" = "$(tdh_normalize_name "${base}")" ]
}

tdh_resolve_cluster_context() {
    local requested="${1:-}"
    tdh_require_client_home || return 1

    local conf_dir=""
    if [ -n "${requested}" ]; then
        while IFS= read -r candidate; do
            [ -n "${candidate}" ] || continue
            if tdh_cluster_matches "${requested}" "${candidate}"; then
                conf_dir="${candidate}"
                break
            fi
        done < <(tdh_collect_conf_dirs)
    else
        conf_dir="$(tdh_active_conf_dir 2>/dev/null || true)"
        if [ -z "${conf_dir}" ]; then
            conf_dir="$(tdh_collect_conf_dirs | head -1)"
        fi
    fi

    [ -n "${conf_dir}" ] || {
        tdh_error "未找到匹配的集群配置: ${requested:-<active>}"
        return 1
    }

    local pair_result kerberos_dir pairing_status
    pair_result="$(tdh_pair_kerberos_dir "${conf_dir}")"
    kerberos_dir="${pair_result%%|*}"
    pairing_status="${pair_result##*|}"

    TDH_CLUSTER_ID="$(basename "${conf_dir}")"
    TDH_CLUSTER_CONF_DIR="${conf_dir}"
    TDH_CLUSTER_KERBEROS_DIR="${kerberos_dir}"
    TDH_CLUSTER_PAIRING_STATUS="${pairing_status}"
    TDH_CLUSTER_REALM="$(tdh_detect_realm_from_conf "${conf_dir}" 2>/dev/null || true)"
    if [ -z "${TDH_CLUSTER_REALM}" ] && [ -n "${kerberos_dir}" ]; then
        TDH_CLUSTER_REALM="$(tdh_detect_realm_from_kerberos_dir "${kerberos_dir}" 2>/dev/null || true)"
    fi
    TDH_CLUSTER_BASE_AUTH="$(tdh_detect_base_auth_mode "${conf_dir}")"
    TDH_CLUSTER_HBASE_AUTH="$(tdh_detect_hbase_auth_mode "${conf_dir}")"
    TDH_CLUSTER_QUARK_AUTH="$(tdh_detect_quark_auth_mode "${conf_dir}")"

    local active_conf
    active_conf="$(tdh_active_conf_dir 2>/dev/null || true)"
    if [ -n "${active_conf}" ] && [ "${active_conf}" = "${conf_dir}" ]; then
        TDH_CLUSTER_IS_ACTIVE="true"
    else
        TDH_CLUSTER_IS_ACTIVE="false"
    fi

    export TDH_CLUSTER_ID TDH_CLUSTER_CONF_DIR TDH_CLUSTER_KERBEROS_DIR TDH_CLUSTER_PAIRING_STATUS
    export TDH_CLUSTER_REALM TDH_CLUSTER_BASE_AUTH TDH_CLUSTER_HBASE_AUTH TDH_CLUSTER_QUARK_AUTH TDH_CLUSTER_IS_ACTIVE
}

tdh_effective_auth_mode() {
    local quark_mode="${TDH_CLUSTER_QUARK_AUTH:-UNKNOWN}"
    local base_mode="${TDH_CLUSTER_BASE_AUTH:-UNKNOWN}"
    case "${quark_mode}" in
        KERBEROS)
            printf 'KERBEROS\n'
            ;;
        LDAP_POSSIBLE)
            printf 'LDAP_POSSIBLE\n'
            ;;
        SIMPLE_OR_NONE)
            printf 'SIMPLE_OR_NONE\n'
            ;;
        *)
            case "${base_mode}" in
                KERBEROS) printf 'KERBEROS\n' ;;
                SIMPLE_OR_NONE) printf 'SIMPLE_OR_NONE\n' ;;
                *) printf 'UNKNOWN\n' ;;
            esac
            ;;
    esac
}

tdh_join_by() {
    local delimiter="$1"
    shift || true
    local first=1 item
    for item in "$@"; do
        [ "${first}" -eq 1 ] || printf '%s' "${delimiter}"
        printf '%s' "${item}"
        first=0
    done
    printf '\n'
}

tdh_collect_quark_candidates() {
    python - "${TDH_CLUSTER_CONF_DIR}" <<'PY'
import os
import re
import sys
import glob
import xml.etree.ElementTree as ET

conf_dir = sys.argv[1]

def path_rank(path):
    base = os.path.basename(os.path.dirname(path)).lower()
    if any(token in base for token in ("main", "primary", "master", "active")):
        return (0, path)
    if any(token in base for token in ("backup", "standby", "slave", "secondary")):
        return (2, path)
    return (1, path)

paths = sorted(glob.glob(os.path.join(conf_dir, "**", "hive-site.xml"), recursive=True), key=path_rank)
seen = set()

def emit(candidate):
    candidate = candidate.replace("\r", "").strip()
    if not candidate:
        return
    candidate = re.sub(r"^(jdbc:hive2|thrift)://", "", candidate)
    candidate = candidate.split("/", 1)[0].strip()
    if not candidate:
        return
    if ":" not in candidate:
        candidate = f"{candidate}:10000"
    if candidate not in seen:
        seen.add(candidate)
        print(candidate)

for path in paths:
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    props = {}
    for prop in tree.findall(".//property"):
        name = prop.findtext("name", default="").strip()
        value = prop.findtext("value", default="").strip()
        if name and value:
            props[name] = value

    raw = props.get("transwarp.docker.inceptor", "")
    if raw:
        for part in re.split(r"[\s,;]+", raw):
            emit(part)
        continue

    host = props.get("hive.server2.thrift.bind.host", "").strip()
    port = props.get("hive.server2.thrift.port", "").strip() or "10000"
    if host:
        emit(f"{host}:{port}")
PY
}

tdh_parse_host_port() {
    local candidate="${1//$'\r'/}"
    local host="${candidate%%:*}"
    local port="${candidate##*:}"
    if [ -z "${host}" ] || [ -z "${port}" ] || [ "${host}" = "${port}" ]; then
        return 1
    fi
    printf '%s %s\n' "${host}" "${port}"
}

tdh_quark_principal_for_host() {
    local host="$1"
    python - "${TDH_CLUSTER_CONF_DIR}" "${host}" <<'PY'
import os
import re
import sys
import glob
import xml.etree.ElementTree as ET

conf_dir, host = sys.argv[1:]

def path_rank(path):
    base = os.path.basename(os.path.dirname(path)).lower()
    if any(token in base for token in ("main", "primary", "master", "active")):
        return (0, path)
    if any(token in base for token in ("backup", "standby", "slave", "secondary")):
        return (2, path)
    return (1, path)

paths = sorted(glob.glob(os.path.join(conf_dir, "**", "hive-site.xml"), recursive=True), key=path_rank)
for path in paths:
    try:
        tree = ET.parse(path)
    except Exception:
        continue
    props = {}
    for prop in tree.findall(".//property"):
        name = prop.findtext("name", default="").strip()
        value = prop.findtext("value", default="").replace("\r", "").strip()
        if name and value:
            props[name] = value
    raw = props.get("transwarp.docker.inceptor", "")
    if raw:
        parts = re.split(r"[\s,;]+", raw)
        if any(p.split(":", 1)[0].replace("thrift://", "").replace("jdbc:hive2://", "").split("/", 1)[0] == host for p in parts if p):
            principal = props.get("hive.server2.authentication.kerberos.principal", "").strip()
            if principal:
                print(principal)
                raise SystemExit(0)
    bind_host = props.get("hive.server2.thrift.bind.host", "").strip()
    if bind_host == host:
        principal = props.get("hive.server2.authentication.kerberos.principal", "").strip()
        if principal:
            print(principal)
            raise SystemExit(0)
raise SystemExit(1)
PY
}

tdh_build_quark_jdbc_url() {
    local host="$1"
    local port="$2"
    local database="${3:-default}"
    local auth_mode="${4:-$(tdh_effective_auth_mode)}"
    local url="jdbc:hive2://${host}:${port}/${database}"
    if [ "${auth_mode}" = "KERBEROS" ]; then
        local principal
        principal="$(tdh_quark_principal_for_host "${host}" 2>/dev/null || true)"
        if [ -z "${principal}" ] && [ -n "${TDH_CLUSTER_REALM:-}" ]; then
            principal="hive/${host}@${TDH_CLUSTER_REALM}"
        fi
        if [ -n "${principal}" ]; then
            url="${url};principal=${principal}"
        fi
    fi
    printf '%s\n' "${url}"
}

tdh_build_quark_beeline_command() {
    local host="$1"
    local port="$2"
    local sql="${3:-SELECT 1;}"
    local auth_mode="${4:-$(tdh_effective_auth_mode)}"
    local url
    url="$(tdh_build_quark_jdbc_url "${host}" "${port}" "default" "${auth_mode}")"
    local cmd
    cmd="beeline -u $(printf '%q' "${url}")"
    if [ "${auth_mode}" = "LDAP_POSSIBLE" ] && [ -n "${TDH_LDAP_USERNAME:-}" ] && [ -n "${TDH_LDAP_PASSWORD:-}" ]; then
        cmd="${cmd} -n $(printf '%q' "${TDH_LDAP_USERNAME}") -p $(printf '%q' "${TDH_LDAP_PASSWORD}")"
    fi
    cmd="${cmd} -e $(printf '%q' "${sql}")"
    printf '%s\n' "${cmd}"
}

tdh_select_quark_server() {
    local auth_mode="$1"
    local stdout_log="$2"
    local stderr_log="$3"
    local explicit_candidate="${4:-${TDH_EXPLICIT_QUARK_SERVER:-}}"
    local candidates=()
    local candidate
    if [ -n "${explicit_candidate}" ]; then
        candidates+=("${explicit_candidate}")
    fi
    while IFS= read -r candidate; do
        [ -n "${candidate}" ] || continue
        if [ "${candidate}" = "${explicit_candidate}" ]; then
            continue
        fi
        candidates+=("${candidate}")
    done < <(tdh_collect_quark_candidates)

    if [ "${#candidates[@]}" -eq 0 ]; then
        echo "未从配置中提取到任何 Quark 候选地址" >>"${stderr_log}"
        return 1
    fi

    TDH_QUARK_CANDIDATES="$(tdh_join_by ',' "${candidates[@]}")"
    export TDH_QUARK_CANDIDATES

    local parsed host port probe_cmd beeline_cmd
    for candidate in "${candidates[@]}"; do
        echo "candidate=${candidate}" >>"${stdout_log}"
        parsed="$(tdh_parse_host_port "${candidate}" 2>/dev/null || true)"
        if [ -z "${parsed}" ]; then
            echo "candidate=${candidate} parse=fail" >>"${stderr_log}"
            continue
        fi
        host="${parsed%% *}"
        port="${parsed##* }"
        probe_cmd="cat < /dev/null > /dev/tcp/${host}/${port}"
        if timeout 2 bash -c "${probe_cmd}" >/dev/null 2>&1; then
            echo "candidate=${candidate} port=open" >>"${stdout_log}"
        else
            echo "candidate=${candidate} port=closed" >>"${stderr_log}"
            continue
        fi

        beeline_cmd="$(tdh_build_quark_beeline_command "${host}" "${port}" "SELECT 1;" "${auth_mode}")"
        if eval "${beeline_cmd}" >/dev/null 2>>"${stderr_log}"; then
            TDH_SELECTED_QUARK_SERVER="${host}"
            TDH_SELECTED_QUARK_PORT="${port}"
            TDH_SELECTED_QUARK_JDBC_URL="$(tdh_build_quark_jdbc_url "${host}" "${port}" "default" "${auth_mode}")"
            export TDH_SELECTED_QUARK_SERVER TDH_SELECTED_QUARK_PORT TDH_SELECTED_QUARK_JDBC_URL
            echo "candidate=${candidate} beeline=success" >>"${stdout_log}"
            return 0
        fi
        echo "candidate=${candidate} beeline=fail" >>"${stderr_log}"
    done

    return 1
}

tdh_collect_available_keytabs() {
    local explicit="${1:-}"
    local seen='|'
    local candidate
    if [ -n "${explicit}" ] && [ -f "${explicit}" ]; then
        printf '%s\n' "${explicit}"
        seen="${seen}${explicit}|"
    fi

    if [ -n "${TDH_CLUSTER_KERBEROS_DIR:-}" ] && [ -d "${TDH_CLUSTER_KERBEROS_DIR}" ]; then
        while IFS= read -r candidate; do
            [ -n "${candidate}" ] || continue
            case "${seen}" in
                *"|${candidate}|"*) ;;
                *)
                    printf '%s\n' "${candidate}"
                    seen="${seen}${candidate}|"
                    ;;
            esac
        done < <(find "${TDH_CLUSTER_KERBEROS_DIR}" -maxdepth 2 -type f -name '*.keytab' 2>/dev/null | sort)
    fi

    while IFS= read -r candidate; do
        [ -n "${candidate}" ] || continue
        case "${seen}" in
            *"|${candidate}|"*) ;;
            *)
                printf '%s\n' "${candidate}"
                seen="${seen}${candidate}|"
                ;;
        esac
    done < <(find "${TDH_CLIENT_HOME}" -maxdepth 1 -type f -name '*.keytab' 2>/dev/null | sort)

    while IFS= read -r candidate; do
        [ -n "${candidate}" ] || continue
        case "${seen}" in
            *"|${candidate}|"*) ;;
            *)
                printf '%s\n' "${candidate}"
                seen="${seen}${candidate}|"
                ;;
        esac
    done < <(find "$PWD" -maxdepth 1 -type f -name '*.keytab' 2>/dev/null | sort)
}

tdh_service_priority_csv() {
    local service="${1:-hive}"
    case "${service}" in
        hdfs) printf 'hdfs,hive,yarn\n' ;;
        yarn) printf 'yarn,hive,hdfs\n' ;;
        *) printf 'hive,hdfs,yarn\n' ;;
    esac
}

tdh_select_keytab() {
    local service="${1:-hive}"
    local explicit="${2:-}"
    TDH_SELECTED_KEYTAB=""
    TDH_SELECTED_PRINCIPAL=""
    TDH_SELECTED_KEYTAB_REASON=""

    if [ "$(tdh_effective_auth_mode)" != "KERBEROS" ]; then
        export TDH_SELECTED_KEYTAB TDH_SELECTED_PRINCIPAL TDH_SELECTED_KEYTAB_REASON
        return 0
    }

    local realm="${TDH_CLUSTER_REALM:-}"
    [ -n "${realm}" ] || {
        tdh_error "无法确定当前集群的 Kerberos Realm"
        return 1
    }

    local priorities priority rank entry best_rank=999 best_count=0 best_entry=""
    IFS=',' read -r -a priorities <<<"$(tdh_service_priority_csv "${service}")"
    local file principal output
    while IFS= read -r file; do
        [ -n "${file}" ] || continue
        output="$(klist -k "${file}" 2>/dev/null || true)"
        while IFS= read -r principal; do
            [ -n "${principal}" ] || continue
            case "${principal}" in
                *@*)
                    ;;
                *)
                    continue
                    ;;
            esac
            local principal_realm service_name current_rank=999 idx=0
            principal_realm="${principal##*@}"
            [ "${principal_realm}" = "${realm}" ] || continue
            service_name="${principal%%/*}"
            for priority in "${priorities[@]}"; do
                if [ "${service_name}" = "${priority}" ]; then
                    current_rank="${idx}"
                    break
                fi
                idx=$((idx + 1))
            done
            if [ "${current_rank}" -lt "${best_rank}" ]; then
                best_rank="${current_rank}"
                best_count=1
                best_entry="${file}|${principal}"
            elif [ "${current_rank}" -eq "${best_rank}" ]; then
                best_count=$((best_count + 1))
            fi
        done < <(printf '%s\n' "${output}" | awk '/@/ {print $NF}')
    done < <(tdh_collect_available_keytabs "${explicit}")

    if [ -z "${best_entry}" ]; then
        tdh_error "未找到与集群 Realm 匹配的 keytab"
        return 1
    }

    if [ "${best_count}" -gt 1 ]; then
        tdh_error "发现多个同优先级的 keytab/principal 候选，请显式指定 keytab"
        return 1
    }

    TDH_SELECTED_KEYTAB="${best_entry%%|*}"
    TDH_SELECTED_PRINCIPAL="${best_entry##*|}"
    TDH_SELECTED_KEYTAB_REASON="service=${service},realm=${realm}"
    export TDH_SELECTED_KEYTAB TDH_SELECTED_PRINCIPAL TDH_SELECTED_KEYTAB_REASON
}

tdh_write_file() {
    local path="$1"
    shift
    mkdir -p "$(dirname "${path}")"
    printf '%s\n' "$@" >"${path}"
}

tdh_json_escape() {
    printf '%s' "$1" | python - <<'PY'
import json,sys
print(json.dumps(sys.stdin.read())[1:-1], end="")
PY
}

tdh_discover_and_write_index() {
    tdh_require_client_home || return 1
    local state_root index_path
    state_root="$(tdh_state_root)"
    mkdir -p "${state_root}"
    index_path="${state_root}/cluster-index.json"

    local active_conf active_kerb
    active_conf="$(tdh_active_conf_dir 2>/dev/null || true)"
    active_kerb="$(tdh_active_kerberos_dir 2>/dev/null || true)"

    local first=1 conf_dir
    {
        printf '[\n'
        while IFS= read -r conf_dir; do
            [ -n "${conf_dir}" ] || continue
            tdh_resolve_cluster_context "$(basename "${conf_dir}")" >/dev/null
            local keytabs_json=""
            local keytab first_keytab=1
            while IFS= read -r keytab; do
                [ -n "${keytab}" ] || continue
                if [ "${first_keytab}" -eq 0 ]; then
                    keytabs_json="${keytabs_json}, "
                fi
                keytabs_json="${keytabs_json}\"$(tdh_json_escape "${keytab}")\""
                first_keytab=0
            done < <(tdh_collect_available_keytabs)

            if [ "${first}" -eq 0 ]; then
                printf ',\n'
            fi
            first=0
            cat <<EOF
  {
    "cluster_id": "$(tdh_json_escape "${TDH_CLUSTER_ID}")",
    "conf_dir": "$(tdh_json_escape "${TDH_CLUSTER_CONF_DIR}")",
    "kerberos_dir": "$(tdh_json_escape "${TDH_CLUSTER_KERBEROS_DIR}")",
    "is_active": ${TDH_CLUSTER_IS_ACTIVE},
    "detected_realm": "$(tdh_json_escape "${TDH_CLUSTER_REALM}")",
    "base_auth_mode": "$(tdh_json_escape "${TDH_CLUSTER_BASE_AUTH}")",
    "service_auth": {
      "hadoop": "$(tdh_json_escape "${TDH_CLUSTER_BASE_AUTH}")",
      "hbase": "$(tdh_json_escape "${TDH_CLUSTER_HBASE_AUTH}")",
      "quark": "$(tdh_json_escape "${TDH_CLUSTER_QUARK_AUTH}")"
    },
    "available_keytabs": [${keytabs_json}],
    "pairing_status": "$(tdh_json_escape "${TDH_CLUSTER_PAIRING_STATUS}")",
    "last_scanned_at": "$(tdh_json_escape "$(tdh_iso_timestamp)")"
  }
EOF
        done < <(tdh_collect_conf_dirs)
        printf '\n]\n'
    } >"${index_path}"

    printf '%s\n' "${index_path}"
}
