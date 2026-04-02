#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

main() {
    local cluster_id="${1:-}"
    local service="${2:-hive}"
    local explicit_keytab="${3:-${TDH_EXPLICIT_KEYTAB:-}}"

    tdh_resolve_cluster_context "${cluster_id}" >/dev/null
    if [ "$(tdh_effective_auth_mode)" != "KERBEROS" ]; then
        cat <<EOF
CLUSTER_ID=${TDH_CLUSTER_ID}
AUTH_MODE=$(tdh_effective_auth_mode)
KEYTAB_FILE=
PRINCIPAL=
REASON=current cluster does not require kerberos
EOF
        return 0
    fi

    tdh_select_keytab "${service}" "${explicit_keytab}"
    cat <<EOF
CLUSTER_ID=${TDH_CLUSTER_ID}
AUTH_MODE=KERBEROS
KEYTAB_FILE=${TDH_SELECTED_KEYTAB}
PRINCIPAL=${TDH_SELECTED_PRINCIPAL}
REASON=${TDH_SELECTED_KEYTAB_REASON}
EOF
}

main "$@"
