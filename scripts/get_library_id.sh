#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${BASE_DIR}/config.yaml"
OUTPUT_FILE="${BASE_DIR}/library_id.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [get_library_id] $*"
}

if [ ! -f "${CONFIG_FILE}" ]; then
    log "ERROR: config.yaml not found at ${CONFIG_FILE}"
    exit 1
fi

TAS_IP=$(grep '^tas_ip:' "${CONFIG_FILE}" | awk '{print $2}')
USER=$(grep '^user:' "${CONFIG_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CONFIG_FILE}" | awk '{print $2}')
LIBRARY_NAME=$(grep '^library_name:' "${CONFIG_FILE}" | awk '{print $2}')

log "Config loaded: TAS_IP=${TAS_IP}, USER=${USER}, LIBRARY_NAME=${LIBRARY_NAME}"

log "Sending GET request to ${TAS_IP}/api/libraries ..."
RESPONSE=$(curl -k -s -u "${USER}:${PASSWORD}" -X GET "${TAS_IP}/api/libraries" 2>&1)
CURL_EXIT=$?

if [ ${CURL_EXIT} -ne 0 ]; then
    log "ERROR: curl request failed with exit code ${CURL_EXIT}"
    log "ERROR: ${RESPONSE}"
    exit 1
fi

log "Response received: ${RESPONSE}"

LIBRARY_ID=$(echo "${RESPONSE}" | jq -r ".libraries[] | select(.name==\"${LIBRARY_NAME}\") | .id" 2>/dev/null)

if [ -z "${LIBRARY_ID}" ] || [ "${LIBRARY_ID}" = "null" ]; then
    log "ERROR: library_id not found for library_name=${LIBRARY_NAME}"
    exit 1
fi

log "Found library_id: ${LIBRARY_ID} for library_name: ${LIBRARY_NAME}"

echo "${LIBRARY_ID}" > "${OUTPUT_FILE}"
log "library_id written to ${OUTPUT_FILE}"

exit 0
