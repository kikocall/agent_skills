#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

main() {
    local cluster_id="${1:-}"
    [ -n "${cluster_id}" ] || {
        tdh_error "用法: switch-cluster.sh <cluster>"
        return 1
    }

    tdh_resolve_cluster_context "${cluster_id}" >/dev/null
    [ "${TDH_CLUSTER_PAIRING_STATUS}" = "paired" ] || {
        tdh_error "集群 ${TDH_CLUSTER_ID} 的 kerberos 目录配对状态为 ${TDH_CLUSTER_PAIRING_STATUS}，无法安全切换"
        return 1
    }

    local conf_link="${TDH_CLIENT_HOME}/conf"
    local kerb_link="${TDH_CLIENT_HOME}/kerberos"
    if [ -e "${conf_link}" ] && [ ! -L "${conf_link}" ]; then
        tdh_error "${conf_link} 不是软链，拒绝覆盖"
        return 1
    fi
    if [ -e "${kerb_link}" ] && [ ! -L "${kerb_link}" ]; then
        tdh_error "${kerb_link} 不是软链，拒绝覆盖"
        return 1
    fi

    rm -f "${conf_link}" "${kerb_link}"
    ln -s "$(basename "${TDH_CLUSTER_CONF_DIR}")" "${conf_link}"
    ln -s "$(basename "${TDH_CLUSTER_KERBEROS_DIR}")" "${kerb_link}"

    tdh_discover_and_write_index >/dev/null
    tdh_resolve_cluster_context "${cluster_id}" >/dev/null

    cat <<EOF
CURRENT_CLUSTER=${TDH_CLUSTER_ID}
CONF_DIR=${TDH_CLUSTER_CONF_DIR}
KERBEROS_DIR=${TDH_CLUSTER_KERBEROS_DIR}
PAIRING_STATUS=${TDH_CLUSTER_PAIRING_STATUS}
AUTH_MODE=$(tdh_effective_auth_mode)
EOF
}

main "$@"
