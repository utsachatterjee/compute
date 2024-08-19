#!/usr/bin/env bash

# Azure Login helper script

ENV=${1:-}

# Check to see if script is being sourced
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [ $sourced -eq 0 ]; then
  echo "[ERROR], this script is meant to be sourced."
  exit 1
fi

# Git root
GITROOT="$(git rev-parse --show-toplevel)/"

# Check if jq is installed
if jq --version 2 &>/dev/null; then
    echo "[INFO] jq already installed"
else
    # Directory of the script
    DIR_PATH="."
    # The tmp dir used, within $DIR
    WORK_DIR=$(mktemp -d "${DIR_PATH}/temp_workXXXXXX")
    # Check if temp dir was created
    if [[ ! "${WORK_DIR}" || ! -d "${WORK_DIR}" ]]; then
        echo "[ERROR] Could not create temp dir"
        exit 1
    fi
    echo "[INFO] jq not installed"
    echo "[INFO] Installing in temp work dir ${WORK_DIR}/bin..."
    mkdir -p ${WORK_DIR}/bin/
    curl -sfL https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64 -o ${WORK_DIR}/bin/jq
    chmod +x ${WORK_DIR}/bin/jq
    export PATH=${WORK_DIR}/bin:$PATH
fi

# Check for .json file in current dir
JSON_FILE="${GITROOT}/utilities/azlogin/azlogin.json"
if [[ "${ENV}" == "" ]]; then
    echo "[INFO] ENV is empty. Setting login environment to sbx..."
    ENV="sbx"
fi

if [[ -f "${JSON_FILE}" ]]; then
    echo ""
    export AZURE_CONFIG_DIR="./.azure"
    export AZURE_EXTENSION_DIR="~/.azure/cliextensions"
    export AZURE_EXTENSION_USE_DYNAMIC_INSTALL="yes_without_prompt"

    echo "[INFO] Exporting ${ENV} environment variables from ${JSON_FILE}..."

    export ARM_CLIENT_ID="$(jq -r ".${ENV}.ARM_CLIENT_ID" ${JSON_FILE})"
    echo "[INFO] ARM_CLIENT_ID = ${ARM_CLIENT_ID}"

    if [[ -z "${ARM_CLIENT_SECRET:-}" ]]; then
        echo "[INFO] No ARM_CLIENT_SECRET in shell environment...exporting from ${JSON_FILE}"
        export ARM_CLIENT_SECRET="$(jq -r ".${ENV}.ARM_CLIENT_SECRET" ${JSON_FILE})"
    fi
    echo "[INFO] ARM_CLIENT_SECRET = **********"

    export ARM_TENANT_ID="$(jq -r ".${ENV}.ARM_TENANT_ID" ${JSON_FILE})"
    echo "[INFO] ARM_TENANT_ID = ${ARM_TENANT_ID}"

    export ARM_SUBSCRIPTION_ID="$(jq -r ".${ENV}.ARM_SUBSCRIPTION_ID" ${JSON_FILE})"
    echo "[INFO] ARM_SUBSCRIPTION_ID = ${ARM_SUBSCRIPTION_ID}"
    echo "[INFO] Variables exported"
    echo ""

    echo "[INFO] Executing az login command with exported variables for ${ENV} in ${JSON_FILE}"
    echo ""
    az login --service-principal -u "${ARM_CLIENT_ID}" -p "${ARM_CLIENT_SECRET}" --tenant "${ARM_TENANT_ID}"
    az account set --subscription="${ARM_SUBSCRIPTION_ID}"
    echo ""
else
    echo "[ERROR] No azlogin.json file found! Try login in manually or fix azlogin.sh and azlogin.json"
fi