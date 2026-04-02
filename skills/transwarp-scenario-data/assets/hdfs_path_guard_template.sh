#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${TARGET_DIR:?missing TARGET_DIR}"
MODE="${MODE:?missing MODE}"
RUN_ID="${RUN_ID:?missing RUN_ID}"

if hdfs dfs -test -e "${TARGET_DIR}"; then
  COUNT_OUTPUT=$(hdfs dfs -count "${TARGET_DIR}")
  FILE_COUNT=$(echo "${COUNT_OUTPUT}" | awk '{print $3}')
  if [ "${FILE_COUNT}" != "0" ]; then
    echo "Target path is not empty: ${TARGET_DIR}" >&2
    exit 1
  fi
fi

echo "HDFS path is safe for mode=${MODE}, run_id=${RUN_ID}: ${TARGET_DIR}"
