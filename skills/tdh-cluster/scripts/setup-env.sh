#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat <<EOF
[INFO] 当前 skill 的标准入口如下：
[INFO] 请先设置 TDH_CLIENT_HOME，然后按任务链路执行对应命令：

  export TDH_CLIENT_HOME="\$HOME/TDH-Client"
  bash "${SCRIPT_DIR}/discover-clusters.sh"
  bash "${SCRIPT_DIR}/switch-cluster.sh" <cluster>
  bash "${SCRIPT_DIR}/check-env.sh" <cluster>
  bash "${SCRIPT_DIR}/check-auth.sh" <cluster>
  bash "${SCRIPT_DIR}/resolve-keytab.sh" <cluster> [service] [explicit_keytab]
  bash "${SCRIPT_DIR}/connect.sh" <cluster> <service|all>
  bash "${SCRIPT_DIR}/run-with-env.sh" <cluster> -- "<command>"
EOF
