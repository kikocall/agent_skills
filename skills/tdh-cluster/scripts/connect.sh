#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/tdh-common.sh"

tdh_contains_service() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        if [ "${item}" = "${needle}" ]; then
            return 0
        fi
    done
    return 1
}

tdh_service_command() {
    local service="$1"
    local auth_mode="$2"
    case "${service}" in
        hdfs)
            printf 'hdfs dfs -ls /\n'
            ;;
        yarn)
            printf 'yarn application -list\n'
            ;;
        hive)
            [ -n "${TDH_SELECTED_QUARK_SERVER:-}" ] || return 1
            [ -n "${TDH_SELECTED_QUARK_PORT:-}" ] || return 1
            tdh_build_quark_beeline_command "${TDH_SELECTED_QUARK_SERVER}" "${TDH_SELECTED_QUARK_PORT}" "SHOW DATABASES;" "${auth_mode}"
            ;;
        kafka)
            printf 'kafka-topics.sh --list --bootstrap-server localhost:9092\n'
            ;;
        zookeeper)
            printf 'zookeeper-client -server localhost:2181\n'
            ;;
        *)
            return 1
            ;;
    esac
}

tdh_write_cases() {
    local path="$1"
    shift
    {
        echo "# 测试案例"
        echo ""
        local service
        for service in "$@"; do
            printf -- "- `%s`: 验证 %s 命令可执行，并记录原始输出\n" "${service}" "${service}"
        done
        if tdh_contains_service "hive" "$@"; then
            echo "- `quark-discovery`: 验证 Quark 候选提取、端口探测和 beeline 探活"
        fi
    } >"${path}"
}

tdh_write_cluster_context() {
    local path="$1"
    local auth_mode="$2"
    {
        echo "CLUSTER_ID=${TDH_CLUSTER_ID}"
        echo "CONF_DIR=${TDH_CLUSTER_CONF_DIR}"
        echo "KERBEROS_DIR=${TDH_CLUSTER_KERBEROS_DIR}"
        echo "PAIRING_STATUS=${TDH_CLUSTER_PAIRING_STATUS}"
        echo "REALM=${TDH_CLUSTER_REALM}"
        echo "AUTH_MODE=${auth_mode}"
        echo "KEYTAB_FILE=${TDH_SELECTED_KEYTAB:-}"
        echo "PRINCIPAL=${TDH_SELECTED_PRINCIPAL:-}"
        echo "KEYTAB_REASON=${TDH_SELECTED_KEYTAB_REASON:-}"
        echo "QUARK_CANDIDATES=${TDH_QUARK_CANDIDATES:-}"
        echo "SELECTED_QUARK_SERVER=${TDH_SELECTED_QUARK_SERVER:-}"
        echo "SELECTED_QUARK_PORT=${TDH_SELECTED_QUARK_PORT:-}"
        echo "SELECTED_JDBC_URL=${TDH_SELECTED_QUARK_JDBC_URL:-}"
    } >"${path}"
}

tdh_append_summary_header() {
    local path="$1"
    {
        echo "# 测试总结"
        echo ""
        echo "## 集群"
        echo "- 集群: ${TDH_CLUSTER_ID}"
        echo "- 认证方式: $(tdh_effective_auth_mode)"
        echo "- keytab: ${TDH_SELECTED_KEYTAB:-N/A}"
        echo "- principal: ${TDH_SELECTED_PRINCIPAL:-N/A}"
        echo "- Quark 候选: ${TDH_QUARK_CANDIDATES:-N/A}"
        echo "- 最终 Quark 节点: ${TDH_SELECTED_QUARK_SERVER:-N/A}"
        echo "- 最终 Quark 端口: ${TDH_SELECTED_QUARK_PORT:-N/A}"
        echo "- 最终 JDBC URL: ${TDH_SELECTED_QUARK_JDBC_URL:-N/A}"
        echo ""
        echo "## SQL 语法排查优先级"
        echo "- ArgoDB 官方文档"
        echo "- Inceptor 官方文档"
        echo "- Hive 官方文档或社区资料"
        echo "- 定向网络检索"
        echo ""
        echo "## 执行结果"
    } >"${path}"
}

tdh_append_summary_result() {
    local path="$1"
    local service="$2"
    local status="$3"
    local stdout_file="$4"
    local stderr_file="$5"
    {
        printf -- "- `%s`: %s\n" "${service}" "${status}"
        printf -- "  stdout: %s\n" "${stdout_file}"
        printf -- "  stderr: %s\n" "${stderr_file}"
        if [ "${service}" = "hive" ] && grep -Eiq 'syntax|cannot recognize input|parseexception' "${stderr_file}" 2>/dev/null; then
            echo "  SQL 语法错误，优先按 ArgoDB -> Inceptor -> Hive -> 定向网络检索 顺序排查。"
        fi
    } >>"${path}"
}

main() {
    local cluster_id="${1:-}"
    local requested_service="${2:-all}"
    [ -n "${cluster_id}" ] || {
        tdh_error "用法: connect.sh <cluster> <service|all>"
        return 1
    }

    tdh_resolve_cluster_context "${cluster_id}" >/dev/null
    tdh_discover_and_write_index >/dev/null
    tdh_resolve_cluster_context "${cluster_id}" >/dev/null

    local auth_mode
    auth_mode="$(tdh_effective_auth_mode)"
    if [ "${auth_mode}" = "KERBEROS" ]; then
        tdh_select_keytab "${requested_service}" "${TDH_EXPLICIT_KEYTAB:-}"
    else
        TDH_SELECTED_KEYTAB=""
        TDH_SELECTED_PRINCIPAL=""
        TDH_SELECTED_KEYTAB_REASON=""
    fi

    local timestamp result_dir runtime_dir
    timestamp="$(tdh_timestamp)"
    result_dir="$(tdh_results_root)/${timestamp}-${TDH_CLUSTER_ID}"
    runtime_dir="$(tdh_runtime_root)/${TDH_CLUSTER_ID}-${timestamp}-$$"
    mkdir -p "${result_dir}/results" "${runtime_dir}"

    local services=()
    if [ "${requested_service}" = "all" ]; then
        services=(hdfs yarn hive kafka zookeeper)
    else
        services=("${requested_service}")
    fi

    local quark_stdout_log="${result_dir}/results/quark-discovery.stdout.log"
    local quark_stderr_log="${result_dir}/results/quark-discovery.stderr.log"
    : >"${quark_stdout_log}"
    : >"${quark_stderr_log}"

    if tdh_contains_service "hive" "${services[@]}"; then
        if ! tdh_select_quark_server "${auth_mode}" "${quark_stdout_log}" "${quark_stderr_log}" "${TDH_EXPLICIT_QUARK_SERVER:-}"; then
            TDH_SELECTED_QUARK_SERVER=""
            TDH_SELECTED_QUARK_PORT=""
            TDH_SELECTED_QUARK_JDBC_URL=""
        fi
    else
        TDH_QUARK_CANDIDATES=""
        TDH_SELECTED_QUARK_SERVER=""
        TDH_SELECTED_QUARK_PORT=""
        TDH_SELECTED_QUARK_JDBC_URL=""
    fi

    TDH_AUTH_OUTPUT_FILE="${result_dir}/auth-detection.txt" bash "${SCRIPT_DIR}/check-auth.sh" "${cluster_id}" >/dev/null
    tdh_write_cases "${result_dir}/cases.md" "${services[@]}"
    tdh_write_cluster_context "${result_dir}/cluster-context.txt" "${auth_mode}"
    : >"${result_dir}/commands.log"
    tdh_append_summary_header "${result_dir}/summary.md"

    local failures=0 service command_text stdout_file stderr_file
    if tdh_contains_service "hive" "${services[@]}" && [ -z "${TDH_SELECTED_QUARK_SERVER:-}" ]; then
        failures=$((failures + 1))
        {
            echo "- `quark-discovery`: FAIL"
            echo "  stdout: ${quark_stdout_log}"
            echo "  stderr: ${quark_stderr_log}"
            echo "  未能从当前集群配置中找到可用的 Quark-Server。"
        } >>"${result_dir}/summary.md"
    fi

    for service in "${services[@]}"; do
        if [ "${service}" = "hive" ] && [ -z "${TDH_SELECTED_QUARK_SERVER:-}" ]; then
            stdout_file="${result_dir}/results/${service}.stdout.log"
            stderr_file="${result_dir}/results/${service}.stderr.log"
            : >"${stdout_file}"
            printf 'quark discovery failed, skip hive validation\n' >"${stderr_file}"
            tdh_append_summary_result "${result_dir}/summary.md" "${service}" "FAIL" "${stdout_file}" "${stderr_file}"
            continue
        fi

        command_text="$(tdh_service_command "${service}" "${auth_mode}")"
        printf '[%s] %s\n' "${service}" "${command_text}" >>"${result_dir}/commands.log"
        stdout_file="${result_dir}/results/${service}.stdout.log"
        stderr_file="${result_dir}/results/${service}.stderr.log"
        if TDH_RESULT_DIR="${result_dir}" TDH_RUNTIME_DIR="${runtime_dir}" TDH_SERVICE_HINT="${service}" \
            bash "${SCRIPT_DIR}/run-with-env.sh" "${cluster_id}" -- "${command_text}" >"${stdout_file}" 2>"${stderr_file}"; then
            tdh_append_summary_result "${result_dir}/summary.md" "${service}" "PASS" "${stdout_file}" "${stderr_file}"
        else
            failures=$((failures + 1))
            tdh_append_summary_result "${result_dir}/summary.md" "${service}" "FAIL" "${stdout_file}" "${stderr_file}"
        fi
    done

    printf 'RESULT_DIR=%s\n' "${result_dir}"
    printf 'SUMMARY=%s\n' "${result_dir}/summary.md"

    if [ "${failures}" -gt 0 ]; then
        return 1
    fi
}

main "$@"
