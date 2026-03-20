#!/bin/sh

set -eu

VERSION="${1:-1.6.0}"
BASE_URL="https://downloads.apache.org/guacamole/${VERSION}/binary"
DOWNLOAD_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/downloads/${VERSION}"
AVAILABLE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/extensions/available"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT INT TERM

mkdir -p "$DOWNLOAD_DIR" "$AVAILABLE_DIR"

download_and_verify() {
    archive_name="$1"

    curl -fsSLo "${DOWNLOAD_DIR}/${archive_name}" "${BASE_URL}/${archive_name}"
    curl -fsSLo "${DOWNLOAD_DIR}/${archive_name}.sha256" "${BASE_URL}/${archive_name}.sha256"

    (
        cd "$DOWNLOAD_DIR"
        sha256sum -c "${archive_name}.sha256"
    )
}

extract_jar() {
    archive_name="$1"
    jar_path="$2"
    output_name="$3"

    tar -xzf "${DOWNLOAD_DIR}/${archive_name}" -C "$WORK_DIR" "$jar_path"
    cp "${WORK_DIR}/${jar_path}" "${AVAILABLE_DIR}/${output_name}"
}

download_and_verify "guacamole-auth-totp-${VERSION}.tar.gz"
download_and_verify "guacamole-auth-sso-${VERSION}.tar.gz"
download_and_verify "guacamole-history-recording-storage-${VERSION}.tar.gz"

extract_jar \
    "guacamole-auth-totp-${VERSION}.tar.gz" \
    "guacamole-auth-totp-${VERSION}/guacamole-auth-totp-${VERSION}.jar" \
    "guacamole-auth-totp-${VERSION}.jar"

extract_jar \
    "guacamole-auth-sso-${VERSION}.tar.gz" \
    "guacamole-auth-sso-${VERSION}/saml/guacamole-auth-sso-saml-${VERSION}.jar" \
    "guacamole-auth-sso-saml-${VERSION}.jar"

extract_jar \
    "guacamole-history-recording-storage-${VERSION}.tar.gz" \
    "guacamole-history-recording-storage-${VERSION}/guacamole-history-recording-storage-${VERSION}.jar" \
    "guacamole-history-recording-storage-${VERSION}.jar"

echo "Extensions downloaded and extracted into ${AVAILABLE_DIR}"
