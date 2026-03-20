#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <jar-file-name>" >&2
    exit 1
fi

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENABLED_DIR="${ROOT_DIR}/extensions/enabled"
JAR_NAME="$1"

rm -f "${ENABLED_DIR:?}/${JAR_NAME}"
echo "Disabled ${JAR_NAME}"
