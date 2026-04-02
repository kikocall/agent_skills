#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_HOME="${TMP_DIR}/home"
FAKE_CLIENT="${FAKE_HOME}/TDH-Client"
FAKE_BIN="${TMP_DIR}/fakebin"
STATE_DIR="${FAKE_HOME}/.codex/tdh-cluster"

mkdir -p "${FAKE_HOME}" "${FAKE_CLIENT}" "${FAKE_BIN}"

pass_count=0
fail_count=0

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if grep -Fq "$needle" <<<"${haystack}"; then
        pass_count=$((pass_count + 1))
        echo "[PASS] ${message}"
    else
        fail_count=$((fail_count + 1))
        echo "[FAIL] ${message}"
        echo "  expected to contain: ${needle}"
        echo "  actual: ${haystack}"
    fi
}

assert_file_exists() {
    local path="$1"
    local message="$2"
    if [ -f "${path}" ]; then
        pass_count=$((pass_count + 1))
        echo "[PASS] ${message}"
    else
        fail_count=$((fail_count + 1))
        echo "[FAIL] ${message}"
        echo "  missing file: ${path}"
    fi
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    if [ "${actual}" = "${expected}" ]; then
        pass_count=$((pass_count + 1))
        echo "[PASS] ${message}"
    else
        fail_count=$((fail_count + 1))
        echo "[FAIL] ${message}"
        echo "  expected exit code ${expected}, got ${actual}"
    fi
}

write_fake_commands() {
    cat >"${FAKE_BIN}/java" <<'EOF'
#!/usr/bin/env bash
echo 'openjdk version "11.0.20"'
EOF
    chmod +x "${FAKE_BIN}/java"

    cat >"${FAKE_BIN}/kinit" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-kt" ]; then
  shift 3
fi
touch "${KRB5CCNAME#FILE:}"
EOF
    chmod +x "${FAKE_BIN}/kinit"

    cat >"${FAKE_BIN}/klist" <<'EOF'
#!/usr/bin/env bash
set -e
if [ "${1:-}" = "-s" ]; then
  test -f "${KRB5CCNAME#FILE:}"
  exit $?
fi
if [ "${1:-}" = "-k" ]; then
  case "${2:-}" in
    *finance.keytab)
      cat <<'OUT'
Keytab name: FILE:/tmp/finance.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   1 hive/finance-node@FINREALM
   1 hdfs/finance-node@FINREALM
OUT
      ;;
    *simple.keytab)
      cat <<'OUT'
Keytab name: FILE:/tmp/simple.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   1 hive/simple-node@SIMPLEREALM
OUT
      ;;
    *)
      cat <<'OUT'
Keytab name: FILE:/tmp/default.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   1 yarn/default-node@FINREALM
OUT
      ;;
  esac
  exit 0
fi
cat <<OUT
Ticket cache: ${KRB5CCNAME:-FILE:/tmp/krb5cc}
Default principal: hive/finance-node@FINREALM
OUT
EOF
    chmod +x "${FAKE_BIN}/klist"

    cat >"${FAKE_BIN}/hdfs" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "dfs" ] && [ "${2:-}" = "-ls" ]; then
  echo "Found 1 items"
  echo "drwxr-xr-x   - hive supergroup          0 2026-04-01 00:00 /warehouse"
  exit 0
fi
exit 1
EOF
    chmod +x "${FAKE_BIN}/hdfs"

    cat >"${FAKE_BIN}/yarn" <<'EOF'
#!/usr/bin/env bash
echo "Total number of applications (application-types: [] and states: [SUBMITTED, ACCEPTED, RUNNING]):0"
EOF
    chmod +x "${FAKE_BIN}/yarn"

    cat >"${FAKE_BIN}/beeline" <<'EOF'
#!/usr/bin/env bash
if printf '%s\n' "$*" | grep -q "bad-quark"; then
  echo "Could not open client transport with JDBC Uri: $*" >&2
  exit 1
fi
if printf '%s\n' "$*" | grep -q "BAD SQL"; then
  echo "Error: line 1:0 cannot recognize input near 'BAD'" >&2
  exit 1
fi
echo "Connected"
echo "default"
EOF
    chmod +x "${FAKE_BIN}/beeline"

    cat >"${FAKE_BIN}/timeout" <<'EOF'
#!/usr/bin/env bash
if [ "$#" -ge 3 ] && [ "$2" = "bash" ] && [ "$3" = "-c" ]; then
  case "$4" in
    *"/dev/tcp/bad-quark/10000"*)
      exit 1
      ;;
    *"/dev/tcp/good-quark/10001"*)
      exit 0
      ;;
  esac
fi
exec "$@"
EOF
    chmod +x "${FAKE_BIN}/timeout"

    cat >"${FAKE_BIN}/kafka-topics.sh" <<'EOF'
#!/usr/bin/env bash
echo "topic_a"
EOF
    chmod +x "${FAKE_BIN}/kafka-topics.sh"

    cat >"${FAKE_BIN}/zookeeper-client" <<'EOF'
#!/usr/bin/env bash
echo "Connecting to ZooKeeper"
EOF
    chmod +x "${FAKE_BIN}/zookeeper-client"
}

write_fake_client() {
    mkdir -p \
      "${FAKE_CLIENt}/alpha-prod-config/hadoop" \
      "${FAKE_CLIENT}/alpha-prod-config/quark-main" \
      "${FAKE_CLIENT}/alpha-prod-config/quark-backup" \
      "${FAKE_CLIENT}/alpha-prod-kerberos" \
      "${FAKE_CLIENT}/beta-simple-conf/hadoop" \
      "${FAKE_CLIENT}/beta-simple-conf/quark-main" \
      "${FAKE_CLIENT}/beta-simple-kerberos"

    cat >"${FAKE_CLIENT}/init.sh" <<'EOF'
#!/usr/bin/env bash
export HADOOP_HOME="${TDH_CLIENT_HOME}/hadoop"
export HADOOP_CONF_DIR="${TDH_CLIENT_HOME}/conf/hadoop"
export HIVE_HOME="${TDH_CLIENT_HOME}/inceptor"
export HIVE_CONF_DIR="${TDH_CLIENT_HOME}/conf/quark-main"
export KAFKA_HOME="${TDH_CLIENT_HOME}/kafka"
export ZOOKEEPER_HOME="${TDH_CLIENT_HOME}/zookeeper"
export PATH="${TDH_CLIENT_HOME}/bin:${PATH}"
EOF
    chmod +x "${FAKE_CLIENT}/init.sh"

    cat >"${FAKE_CLIENT}/alpha-prod-config/hadoop/core-site.xml" <<'EOF'
<configuration>
  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value>
  </property>
</configuration>
EOF

    cat >"${FAKE_CLIENT}/alpha-prod-config/quark-main/hive-site.xml" <<'EOF'
<configuration>
  <property>
    <name>transwarp.docker.inceptor</name>
    <value>bad-quark:10000</value>
  </property>
  <property>
    <name>hive.server2.authentication</name>
    <value>KERBEROS</value>
  </property>
  <property>
    <name>hive.server2.authentication.kerberos.principal</name>
    <value>hive/bad-quark@FINREALM</value>
  </property>
</configuration>
EOF

    cat >"${FAKE_CLIENT}/alpha-prod-config/quark-backup/hive-site.xml" <<'EOF'
<configuration>
  <property>
    <name>transwarp.docker.inceptor</name>
    <value>good-quark:10001</value>
  </property>
  <property>
    <name>hive.server2.authentication</name>
    <value>KERBEROS</value>
  </property>
  <property>
    <name>hive.server2.authentication.kerberos.principal</name>
    <value>hive/good-quark@FINREALM</value>
  </property>
</configuration>
EOF

    cat >"${FAKE_CLIENT}/alpha-prod-kerberos/krb5.conf" <<'EOF'
[libdefaults]
default_realm = FINREALM
EOF
    touch "${FAKE_CLIENT}/alpha-prod-kerberos/finance.keytab"

    cat >"${FAKE_CLIENT}/beta-simple-conf/hadoop/core-site.xml" <<'EOF'
<configuration>
  <property>
    <name>hadoop.security.authentication</name>
    <value>simple</value>
  </property>
</configuration>
EOF

    cat >"${FAKE_CLIENT}/beta-simple-conf/quark-main/hive-site.xml" <<'EOF'
<configuration>
  <property>
    <name>hive.server2.thrift.port</name>
    <value>10000</value>
  </property>
</configuration>
EOF

    cat >"${FAKE_CLIENt}/beta-simple-kerberos/krb5.conf" <<'EOF'
[libdefaults]
default_realm = SIMPLEREALM
EOF
    touch "${FAKE_CLIENT}/beta-simple-kerberos/simple.keytab"

    ln -s "alpha-prod-config" "${FAKE_CLIENt}/conf"
    ln -s "alpha-prod-kerberos" "${FAKE_CLIENt}/kerberos"
}

run_test_red_phase() {
    local output
    local status=0
    output="$(
      HOME="${FAKE_HOME}" TDH_CLIENT_HOME="${FAKE_CLIENT}" PATH="${FAKE_BIN}:${PATH}" \
      bash "${ROOT_DIR}/scripts/discover-clusters.sh" 2>&1
    )" || status=$?
    assert_exit_code "${status}" "0" "discover-clusters 脚本存在且可执行"
    assert_file_exists "${STATE_DIR}/cluster-index.json" "discover-clusters 会生成索引文件"
    assert_contains "${output}" "alpha-prod-config" "discover-clusters 输出扫描到的集群"

    status=0
    output="$(
      HOME="${FAKE_HOME}" TDH_CLIENT_HOME="${FAKE_CLIENT}" PATH="${FAKE_BIN}:${PATH}" \
      bash "${ROOT_DIR}/scripts/check-auth.sh" alpha-prod-config 2>&1
    )" || status=$?
    assert_exit_code "${status}" "0" "check-auth 脚本存在且可执行"
    assert_contains "${output}" "KERBEROS" "check-auth 能识别 Kerberos 集群"

    status=0
    output="$(
      HOME="${FAKE_HOME}" TDH_CLIENT_HOME="${FAKE_CLIENT}" PATH="${FAKE_BIN}:${PATH}" \
      bash "${ROOT_DIR}/scripts/resolve-keytab.sh" alpha-prod-config hive 2>&1
    )" || status=$?
    assert_exit_code "${status}" "0" "resolve-keytab 脚本存在且可执行"
    assert_contains "${output}" "finance.keytab" "resolve-keytab 会选择当前集群匹配的 keytab"

    status=0
    output="$(
      HOME="${FAKE_HOME}" TDH_CLIENT_HOME="${FAKE_CLIENT}" PATH="${FAKE_BIN}:${PATH}" \
      bash "${ROOT_DIR}/scripts/run-with-env.sh" alpha-prod-config -- "printf '%s %s' \"\${HADOOP_HOME}\" \"\${KRB5_CONFIG}\"" 2>&1
    )" || status=$?
    assert_exit_code "${status}" "0" "run-with-env 脚本存在且可执行"
    assert_contains "${output}" "${FAKE_CLIENt}/hadoop" "run-with-env 能在新 shell 中拿到初始化环境"

    status=0
    output="$(
      HOME="${FAKE_HOME}" TDH_CLIENT_HOME="${FAKE_CLIENT}" PATH="${FAKE_BIN}:${PATH}" \
      bash "${ROOT_DIR}/scripts/connect.sh" alpha-prod-config hive 2>&1
    )" || status=$?
    assert_exit_code "${status}" "0" "connect 脚本存在且可执行"
    assert_contains "${output}" "summary.md" "connect 会输出本地结果目录"

    local result_dir
    result_dir="$(printf '%s\n' "${output}" | awk -F= '/^RESULT_DIR=/{print $2; exit}')"
    assert_file_exists "${result_dir}/results/quark-discovery.stdout.log" "connect 会输出 Quark 发现日志"
    assert_file_exists "${result_dir}/results/quark-discovery.stderr.log" "connect 会输出 Quark 错误日志"
    assert_contains "$(cat "${result_dir}/cluster-context.txt")" "SELECTED_QUARK_SERVER=good-quark" "cluster-context 会记录最终选中的 Quark 节点"
    assert_contains "$(cat "${result_dir}/cluster-context.txt")" "SELECTED_JDBC_URL=jdbc:hive2://good-quark:10001/default;principal=hive/good-quark@FINREALM" "cluster-context 会记录 JDBC URL"
    assert_contains "$(cat "${result_dir}/results/quark-discovery.stdout.log")" "bad-quark:10000" "Quark 发现日志会记录失败候选"
    assert_contains "$(cat "${result_dir}/results/quark-discovery.stdout.log")" "good-quark:10001" "Quark 发现日志会记录成功候选"
    assert_contains "$(cat "${ROOT_DIR}/SKILL.md")" "https://www.transwarp.cn/doc" "SKILL.md 包含官方文档总入口"
    assert_contains "$(cat "${ROOT_DIR}/SKILL.md")" "https://kb.transwarp.cn" "SKILL.md 包含 Knowledge Base 入口"
}

write_fake_commands
write_fake_client
run_test_red_phase

echo ""
echo "pass=${pass_count} fail=${fail_count}"
if [ "${fail_count}" -gt 0 ]; then
    exit 1
fi
