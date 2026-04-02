#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

main() {
    local index_path
    index_path="$(tdh_discover_and_write_index)"
    tdh_info "索引已刷新: ${index_path}"

    local conf_dir
    while IFS= read -r conf_dir; do
        [ -n "${conf_dir}" ] || continue
        tdh_resolve_cluster_context "$(basename "${conf_dir}")" >/dev/null
        printf '%s\tactive=%s\tauth=%s\tpairing=%s\n' \
            "${TDH_CLUSTER_ID}" \
            "${TDH_CLUSTER_IS_ACTIVE}" \
            "$(tdh_effective_auth_mode)" \
            "${TDH_CLUSTER_PAIRING_STATUS}"
    done < <(tdh_collect_conf_dirs)
}

main "$@"
