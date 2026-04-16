#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${BASE_DIR}/config.yaml"
LIBRARY_ID_FILE="${BASE_DIR}/library_id.txt"
OUTPUT_FILE="${BASE_DIR}/running_id.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [sessionstart] $*"
}

if [ ! -f "${CONFIG_FILE}" ]; then
    log "ERROR: config.yaml not found at ${CONFIG_FILE}"
    exit 1
fi

if [ ! -f "${LIBRARY_ID_FILE}" ]; then
    log "ERROR: library_id.txt not found at ${LIBRARY_ID_FILE}, please run get_library_id.sh first"
    exit 1
fi

TAS_IP=$(grep '^tas_ip:' "${CONFIG_FILE}" | awk '{print $2}')
USER=$(grep '^user:' "${CONFIG_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CONFIG_FILE}" | awk '{print $2}')
CASE_NAME=$(grep '^case_name:' "${CONFIG_FILE}" | awk '{print $2}')
LIBRARY_ID=$(cat "${LIBRARY_ID_FILE}" | tr -d '[:space:]')

log "Config loaded: TAS_IP=${TAS_IP}, USER=${USER}, LIBRARY_ID=${LIBRARY_ID}, CASE_NAME=${CASE_NAME}"

POST_URL="${TAS_IP}/api/runningTests"
POST_DATA="{\"library\":${LIBRARY_ID},\"name\":\"${CASE_NAME}\"}"

log "Sending POST request to ${POST_URL} with data: ${POST_DATA}"
RESPONSE=$(curl -k -s -u "${USER}:${PASSWORD}" -X POST "${POST_URL}" \
    -H "Content-Type: application/json" \
    -d "${POST_DATA}" 2>&1)
CURL_EXIT=$?

if [ ${CURL_EXIT} -ne 0 ]; then
    log "ERROR: curl request failed with exit code ${CURL_EXIT}"
    log "ERROR: ${RESPONSE}"
    exit 1
fi

log "Start session response: ${RESPONSE}"

log "Querying running_id for library_id=${LIBRARY_ID}, case_name=${CASE_NAME} with state RUNNING ..."
GET_URL="${TAS_IP}/api/runningTests"
RUNNING_RESPONSE=$(curl -k -s -u "${USER}:${PASSWORD}" -X GET "${GET_URL}" 2>&1)
CURL_EXIT=$?

if [ ${CURL_EXIT} -ne 0 ]; then
    log "ERROR: curl request failed with exit code ${CURL_EXIT}"
    log "ERROR: ${RUNNING_RESPONSE}"
    exit 1
fi

log "Running tests response: ${RUNNING_RESPONSE}"

RUNNING_ID=$(echo "${RUNNING_RESPONSE}" | jq -r ".runningTests[] | select(.library==${LIBRARY_ID} and .name==\"${CASE_NAME}\" and .testStateOrStep==\"RUNNING\") | .id" 2>/dev/null | head -1)

if [ -z "${RUNNING_ID}" ] || [ "${RUNNING_ID}" = "null" ]; then
    log "ERROR: running_id not found for library_id=${LIBRARY_ID}, case_name=${CASE_NAME} with state RUNNING"
    log "Trying to find any matching record without state filter ..."
    RUNNING_ID=$(echo "${RUNNING_RESPONSE}" | jq -r ".runningTests[] | select(.library==${LIBRARY_ID} and .name==\"${CASE_NAME}\") | .id" 2>/dev/null | head -1)
    if [ -z "${RUNNING_ID}" ] || [ "${RUNNING_ID}" = "null" ]; then
        log "ERROR: No matching running test found at all"
        exit 1
    fi
    log "WARNING: Found running_id=${RUNNING_ID} but session may not be in RUNNING state"
fi

log "Found running_id: ${RUNNING_ID}"

echo "${RUNNING_ID}" > "${OUTPUT_FILE}"
log "running_id written to ${OUTPUT_FILE}"

exit 0
