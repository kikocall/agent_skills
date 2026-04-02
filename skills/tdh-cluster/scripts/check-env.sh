#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

main() {
    local cluster_id="${1:-}"
    tdh_require_client_home || return 1
    tdh_discover_and_write_index >/dev/null

    local java_ok="missing"
    local kerberos_ok="missing"
    if command -v java >/dev/null 2>&1; then
        java_ok="$(java -version 2>&1 | head -1)"
    fi
    if command -v kinit >/dev/null 2>&1; then
        kerberos_ok="installed"
    fi

    local active_cluster=""
    active_cluster="$(basename "$(tdh_active_conf_dir 2>/dev/null || true)")"

    cat <<EOF
TDH_CLIENT_HOME=${TDH_CLIENT_HOME}
JAVA_STATUS=${java_ok}
KERBEROS_CLIENT=${kerberos_ok}
INDEX_FILE=$(tdh_state_root)/cluster-index.json
ACTIVE_CLUSTER=${active_cluster}
EOF

    if [ -n "${cluster_id}" ]; then
        tdh_resolve_cluster_context "${cluster_id}" >/dev/null
        cat <<EOF
CLUSTER_ID=${TDH_CLUSTER_ID}
PAIRING_STATUS=${TDH_CLUSTER_PAIRING_STATUS}
AUTH_MODE=$(tdh_effective_auth_mode)
EOF
    fi
}

main "$@"
