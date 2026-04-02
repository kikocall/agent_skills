#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

main() {
    local cluster_id="${1:-}"
    tdh_resolve_cluster_context "${cluster_id}" >/dev/null
    tdh_discover_and_write_index >/dev/null
    tdh_resolve_cluster_context "${cluster_id}" >/dev/null

    local effective
    effective="$(tdh_effective_auth_mode)"
    local quark_candidates
    quark_candidates="$(tdh_collect_quark_candidates | paste -sd ',' -)"

    cat <<EOF
CLUSTER_ID=${TDH_CLUSTER_ID}
CONF_DIR=${TDH_CLUSTER_CONF_DIR}
KERBEROS_DIR=${TDH_CLUSTER_KERBEROS_DIR}
PAIRING_STATUS=${TDH_CLUSTER_PAIRING_STATUS}
REALM=${TDH_CLUSTER_REALM}
HADOOP_AUTH=${TDH_CLUSTER_BASE_AUTH}
HBASE_AUTH=${TDH_CLUSTER_HBASE_AUTH}
QUARK_AUTH=${TDH_CLUSTER_QUARK_AUTH}
QUARK_CANDIDATES=${quark_candidates}
EFFECTIVE_AUTH=${effective}
EOF

    if [ -n "${TDH_AUTH_OUTPUT_FILE:-}" ]; then
        tdh_write_file "${TDH_AUTH_OUTPUT_FILE}" \
            "CLUSTER_ID=${TDH_CLUSTER_ID}" \
            "CONF_DIR=${TDH_CLUSTER_CONF_DIR}" \
            "KERBEROS_DIR=${TDH_CLUSTER_KERBEROS_DIR}" \
            "PAIRING_STATUS=${TDH_CLUSTER_PAIRING_STATUS}" \
            "REALM=${TDH_CLUSTER_REALM}" \
            "HADOOP_AUTH=${TDH_CLUSTER_BASE_AUTH}" \
            "HBASE_AUTH=${TDH_CLUSTER_HBASE_AUTH}" \
            "QUARK_AUTH=${TDH_CLUSTER_QUARK_AUTH}" \
            "QUARK_CANDIDATES=${quark_candidates}" \
            "EFFECTIVE_AUTH=${effective}"
    fi
}

main "$@"
