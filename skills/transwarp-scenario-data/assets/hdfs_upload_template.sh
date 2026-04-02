#!/usr/bin/env bash
set -euo pipefail

LOCAL_BATCH_DIR="${LOCAL_BATCH_DIR:?missing LOCAL_BATCH_DIR}"
TARGET_DIR="${TARGET_DIR:?missing TARGET_DIR}"

hdfs dfs -mkdir -p "${TARGET_DIR}"
hdfs dfs -put -f "${LOCAL_BATCH_DIR}"/* "${TARGET_DIR}/"
hdfs dfs -ls "${TARGET_DIR}"
