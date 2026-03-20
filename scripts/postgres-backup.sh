#!/bin/sh

set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-86400}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP_FORMAT="${TIMESTAMP_FORMAT:-%Y%m%d-%H%M%S}"

mkdir -p "$BACKUP_DIR"

run_backup() {
    timestamp="$(date +"${TIMESTAMP_FORMAT}")"
    tmp_file="${BACKUP_DIR}/guacamole_${timestamp}.dump.tmp"
    final_file="${BACKUP_DIR}/guacamole_${timestamp}.dump"

    pg_dump \
        -h "${POSTGRES_HOST}" \
        -p "${POSTGRES_PORT}" \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        -Fc \
        -f "${tmp_file}"

    mv "${tmp_file}" "${final_file}"
    find "${BACKUP_DIR}" -type f -name '*.dump' -mtime +"${BACKUP_RETENTION_DAYS}" -delete
}

while true; do
    run_backup
    sleep "${BACKUP_INTERVAL_SECONDS}"
done
