#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

main() {
    local cluster_id="${1:-}"
    shift || true

    if [ "${1:-}" != "--" ]; then
        tdh_error "用法: run-with-env.sh <cluster> -- <command>"
        return 1
    fi
    shift || true
    local command_text="$*"
    [ -n "${command_text}" ] || {
        tdh_error "缺少要执行的命令"
        return 1
    }

    tdh_resolve_cluster_context "${cluster_id}" >/dev/null

    local auth_mode runtime_root runtime_dir run_id bootstrap_file ccache_path result_dir
    auth_mode="$(tdh_effective_auth_mode)"
    runtime_root="$(tdh_runtime_root)"
    mkdir -p "${runtime_root}"
    run_id="${TDH_RUN_ID:-${TDH_CLUSTER_ID}-$(tdh_timestamp)-$$}"
    runtime_dir="${TDH_RUNTIME_DIR:-${runtime_root}/${run_id}}"
    mkdir -p "${runtime_dir}"
    bootstrap_file="${runtime_dir}/bootstrap.sh"
    ccache_path="${runtime_dir}/krb5cc"
    result_dir="${TDH_RESULT_DIR:-}"

    if [ "${auth_mode}" = "LDAP_POSSIBLE" ] && { [ -z "${TDH_LDAP_USERNAME:-}" ] || [ -z "${TDH_LDAP_PASSWORD:-}" ]; }; then
        tdh_error "当前集群可能使用 LDAP 认证，请先提供 TDH_LDAP_USERNAME 和 TDH_LDAP_PASSWORD"
        return 1
    fi

    local keytab_file="" principal=""
    if [ "${auth_mode}" = "KERBEROS" ]; then
        tdh_select_keytab "${TDH_SERVICE_HINT:-hive}" "${TDH_EXPLICIT_KEYTAB:-}"
        keytab_file="${TDH_SELECTED_KEYTAB}"
        principal="${TDH_SELECTED_PRINCIPAL}"
    fi

    cat >"${bootstrap_file}" <<EOF
#!/usr/bin/env bash
export TDH_CLIENT_HOME="$(printf '%s' "${TDH_CLIENT_HOME}")"
export TDH_CLUSTER_ID="$(printf '%s' "${TDH_CLUSTER_ID}")"
export TDH_CLUSTER_CONF_DIR="$(printf '%s' "${TDH_CLUSTER_CONF_DIR}")"
export TDH_CLUSTER_KERBEROS_DIR="$(printf '%s' "${TDH_CLUSTER_KERBEROS_DIR}")"
export KRB5_CONFIG="$(printf '%s' "${TDH_CLUSTER_KERBEROS_DIR}/krb5.conf")"
export KRB5CCNAME="FILE:${ccache_path}"
source "\${TDH_CLIENT_HOME}/init.sh" n n >/dev/null 2>&1
EOF

    if [ "${auth_mode}" = "KERBEROS" ]; then
        cat >>"${bootstrap_file}" <<EOF
if ! klist -s >/dev/null 2>&1; then
    kinit -kt "$(printf '%s' "${keytab_file}")" "$(printf '%s' "${principal}")" >/dev/null 2>&1
fi
EOF
    fi

    chmod +x "${bootstrap_file}"

    local status=0
    if bash --rcfile "${bootstrap_file}" -i -c "${command_text}"; then
        status=0
    else
        status=$?
        if bash -i -c "source \"${bootstrap_file}\"; ${command_text}"; then
            status=0
        fi
    fi

    if [ "${status}" -ne 0 ] && [ -n "${result_dir}" ]; then
        cp "${bootstrap_file}" "${result_dir}/bootstrap.snapshot.sh"
    fi

    rm -f "${bootstrap_file}"
    return "${status}"
}

main "$@"
