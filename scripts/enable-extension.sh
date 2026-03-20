#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <jar-file-name>" >&2
    exit 1
fi

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
AVAILABLE_DIR="${ROOT_DIR}/extensions/available"
ENABLED_DIR="${ROOT_DIR}/extensions/enabled"
JAR_NAME="$1"

mkdir -p "$ENABLED_DIR"

if [ ! -f "${AVAILABLE_DIR}/${JAR_NAME}" ]; then
    echo "Jar not found: ${AVAILABLE_DIR}/${JAR_NAME}" >&2
    exit 1
fi

cp "${AVAILABLE_DIR}/${JAR_NAME}" "${ENABLED_DIR}/${JAR_NAME}"
echo "Enabled ${JAR_NAME}"
