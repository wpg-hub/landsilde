#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${BASE_DIR}/config.yaml"
RUNNING_ID_FILE="${BASE_DIR}/running_id.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [del_running_id] $*"
}

if [ ! -f "${CONFIG_FILE}" ]; then
    log "ERROR: config.yaml not found at ${CONFIG_FILE}"
    exit 1
fi

if [ ! -f "${RUNNING_ID_FILE}" ]; then
    log "ERROR: running_id.txt not found at ${RUNNING_ID_FILE}, nothing to delete"
    exit 1
fi

TAS_IP=$(grep '^tas_ip:' "${CONFIG_FILE}" | awk '{print $2}')
USER=$(grep '^user:' "${CONFIG_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CONFIG_FILE}" | awk '{print $2}')
RUNNING_ID=$(cat "${RUNNING_ID_FILE}" | tr -d '[:space:]')

log "Config loaded: TAS_IP=${TAS_IP}, USER=${USER}, RUNNING_ID=${RUNNING_ID}"

DELETE_URL="${TAS_IP}/api/runningTests/${RUNNING_ID}"

log "Sending DELETE request to remove running test resource: ${DELETE_URL}"
RESPONSE=$(curl -k -s -u "${USER}:${PASSWORD}" -X DELETE "${DELETE_URL}" 2>&1)
CURL_EXIT=$?

if [ ${CURL_EXIT} -ne 0 ]; then
    log "ERROR: curl request failed with exit code ${CURL_EXIT}"
    log "ERROR: ${RESPONSE}"
    exit 1
fi

log "Delete running test response: ${RESPONSE}"
log "Running test ${RUNNING_ID} deleted successfully"

rm -f "${RUNNING_ID_FILE}"
log "Cleaned up ${RUNNING_ID_FILE}"

exit 0
