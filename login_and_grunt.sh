#!/bin/bash
set -euo pipefail

ENV=${1:-}
TG_ARG=${2:-}
IMPL_FOLDER=${3:-}
MODULE=${4:-}
REGION=${5:-east-us}

# Script Variables
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd -P)"

# Set default ENV if empty
if [[ "${ENV}" == "" ]]; then
    echo "[INFO] ENV is empty. Setting login environment to sbx..."
    ENV="sbx"
fi

if [ -z ${CI+x} ]; then
    CI="false"
    echo "[INFO] CI is empty setting CI to ${CI}..."
    mkdir -p "/tmp/.terraform.d/plugin-cache"
    export TF_PLUGIN_CACHE_DIR="/tmp/.terraform.d/plugin-cache"
    TG_NONITERACTIVE_DESTROY=""
else
    mkdir -p "${WORKSPACE}/../.terraform.d/plugin-cache"
    export TF_PLUGIN_CACHE_DIR="${WORKSPACE}/../.terraform.d/plugin-cache"
    TG_NONITERACTIVE_DESTROY="--terragrunt-non-interactive"
fi

# Set impl path
IMPLEMENTATION_DIR="${SCRIPT_PATH}/impl/${IMPL_FOLDER}"

# Help instructions
function help() {
    echo "Usage: ./login_and_grunt.sh <env> <tg_arg>
                            [dev] [validate]
                            [tst] [validate-all]
                            [prd] [init]
                            [sbx] [init-all]
                                  [plan]
                                  [plan-all]
                                  [apply]
                                  [apply-all]
                                  [fmt]
                                  [clean]


    ex: ./loging_and_grunt.sh sbx plan

    Optional Usage: ./login_and_grunt.sh <env> <tg_arg> <module> <region>

    ex: ./loging_and_grunt.sh sbx plan base west-us
    "
    exit 2
}

# Do az login and source environment variables
function az_login() {
    source ./utilities/azlogin/azlogin.sh "${ENV}"
}

# Clean terragrunt cache
function clean() {
    echo "[INFO] Found the following files:"
    find . -type d -name ".terragrunt-cache"
    echo "[INFO] Removing, if any files exists..."
    find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;
}

# Terragrunt commands to use
function tg_commands() {
    TG_VALIDATE="terragrunt run-all validate"
    TG_INIT="terragrunt run-all init"
    TG_PLAN="terragrunt run-all plan --terragrunt-non-interactive -lock-timeout=5m"
    TG_APPLY="terragrunt run-all apply --terragrunt-non-interactive -lock-timeout=5m"
    TG_DESTROY="terragrunt run-all destroy ${TG_NONITERACTIVE_DESTROY} -lock-timeout=5m"
}

# Terragrunt and Terraform Check format
function tg_tf_fmt() {
    TG_CHECK_FMT="terragrunt hclfmt --terragrunt-check"
    TF_CHECK_FMT="terraform fmt -check -recursive"

    echo "[INFO] Checking Terragrunt formatting..."
    if (cd ${SCRIPT_PATH} && exec bash -c "${TG_CHECK_FMT}"); then
        echo "[INFO] Terragrunt files are correctly formatted"
    fi

    echo "[INFO] Checking Terraform formatting..."
    if (cd ${SCRIPT_PATH} && exec bash -c "${TF_CHECK_FMT}"); then
        echo "[INFO] Terraform files are correctly formatted"
    fi
}

# Store changed files in a variable
function terragrunt_with_diff() {
    current_commit=""
    previous_commit=""
    if [[ $CI == "true" ]]; then
        echo "[INFO] GIT_COMMIT=${GIT_COMMIT}"
        if [[ -z "${GIT_COMMIT}" ]]; then
            echo 'ERROR: `GIT_COMMIT` was not defined!'
            exit 1
        fi

        if [ ! -v GIT_PREVIOUS_SUCCESSFUL_COMMIT ]; then
            if [ -v CHANGE_TARGET ]; then
                GIT_PREVIOUS_SUCCESSFUL_COMMIT="$(git rev-parse origin/${CHANGE_TARGET})"
            else
                GIT_PREVIOUS_SUCCESSFUL_COMMIT="${GIT_COMMIT}"
            fi
        fi

        echo "[INFO] GIT_PREVIOUS_SUCCESSFUL_COMMIT=${GIT_PREVIOUS_SUCCESSFUL_COMMIT}"
        if [[ -z "${GIT_PREVIOUS_SUCCESSFUL_COMMIT}" ]]; then
            echo 'ERROR: Either `GIT_PREVIOUS_SUCCESSFUL_COMMIT` was not defined, or user did not'
            echo 'override with previous commit.'
            exit 2
        fi

        current_commit="${GIT_COMMIT}"
        previous_commit="${GIT_PREVIOUS_SUCCESSFUL_COMMIT}"
    else
        current_commit="$(git rev-parse HEAD)"
        previous_commit="$(git rev-parse origin/$(git symbolic-ref --short HEAD))"
    fi

    echo "[INFO] Comparing git commit '${previous_commit}' to '${current_commit}' ..."
    CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -m -r ${previous_commit} ${current_commit})

    if [[ ! -z "${CHANGED_FILES}" ]]; then
        # Iterate over changed files
        COUNT=0
        IGNORED_FILES=""
        for f in ${CHANGED_FILES}; do
            # Changed files located in impl
            if [[ "${f}" =~ impl/mg.* ]]  && ! [[ "${f}" =~ env.hcl$ ]]; then
                TG_PLAN_OUT_PATH="${SCRIPT_PATH}/$(dirname $f)/.terragrunt-cache/$(basename $(dirname $f).tfplan)"

                # Only do azlogin once
                if [ $COUNT -eq 0 ]; then az_login; fi
                COUNT=$((COUNT + 1))

                # On plan output a .tfplan
                if [[ "${TG_ARG}" == "plan" ]]; then TG_COMMAND="${TG_PLAN} -out ${TG_PLAN_OUT_PATH}"; fi

                # On apply use .tfplan as an input
                if [[ "${TG_ARG}" == "apply" ]]; then TG_COMMAND="${TG_APPLY} ${TG_PLAN_OUT_PATH}"; fi

                # Run target
                if test -d $(dirname $f); then
                    echo "[INFO] Running ${TG_COMMAND} in ${f} for module $(dirname $f)"
                    (cd $(dirname $f) && exec bash -c "${TG_COMMAND}")
                else
                    echo ""
                    echo "[INFO] $(dirname $f) not found...continue"
                    echo ""
                fi
            else
                IGNORED_FILES+="${f} "
            fi
        done

        if [[ ! -z "${IGNORED_FILES}" ]]; then
            echo -e "[INFO] The following changed files were ignored: ${IGNORED_FILES}"
        fi
    else
        echo
        echo "[INFO] No changes to apply"
        exit 0
    fi
}

function terragrunt_module() {
    az_login
    MODULE_LOCATION="${IMPLEMENTATION_DIR}/${MODULE}"
    TG_PLAN_OUT_PATH="${MODULE_LOCATION}/.terragrunt-cache/${MODULE}.tfplan"

    # On plan output a .tfplan
    if [[ "${TG_ARG}" == "plan" ]]; then TG_COMMAND="${TG_PLAN} -out ${TG_PLAN_OUT_PATH}"; fi

    # On apply use .tfplan as an input
    if [[ "${TG_ARG}" == "apply" ]]; then TG_COMMAND="${TG_APPLY} ${TG_PLAN_OUT_PATH}"; fi

    echo "[INFO] Running ${TG_COMMAND} in ${MODULE_LOCATION} on MODULE ${MODULE}"
    echo ""
    (cd "${MODULE_LOCATION}" && exec bash -c "${TG_COMMAND}")
}

function terragrunt_all {
    az_login
    echo "[INFO] Running ${TG_COMMAND} in ${IMPLEMENTATION_DIR} on ALL modules"
    echo ""
    (cd ${IMPLEMENTATION_DIR} && exec bash -c "${TG_COMMAND}")
}

# Main execute logic
function terragrunt() {
    echo "[INFO] Terragrunt command: ${TG_ARG}"
    reg="${TG_ARG}"
    if [[ ! -z "${MODULE}" ]]; then
        terragrunt_module
    elif [[ "${reg}" =~ "all" ]]; then
        terragrunt_all
    else
        terragrunt_with_diff
    fi
}

case $TG_ARG in
fmt)
    tg_tf_fmt
    ;;
clean)
    clean
    ;;
validate)
    tg_commands
    TG_COMMAND="${TG_VALIDATE}"
    terragrunt
    ;;
validate-all)
    tg_commands
    TG_COMMAND="${TG_VALIDATE}"
    terragrunt
    ;;
init)
    tg_commands
    TG_COMMAND="${TG_INIT}"
    terragrunt
    ;;
init-all)
    tg_commands
    TG_COMMAND="${TG_INIT}"
    terragrunt
    ;;
plan)
    tg_commands
    TG_COMMAND="${TG_VALIDATE}; ${TG_PLAN}"
    terragrunt
    ;;
plan-all)
    tg_commands
    TG_COMMAND="${TG_VALIDATE}; ${TG_PLAN}"
    terragrunt
    ;;
apply)
    tg_commands
    TG_COMMAND="${TG_APPLY}"
    terragrunt
    ;;
apply-all)
    tg_commands
    TG_COMMAND="${TG_APPLY}"
    terragrunt
    ;;
destroy)
    tg_commands
    TG_COMMAND="${TG_DESTROY}"
    terragrunt
    ;;
help)
    help
    ;;
*)
    echo "Unexpected option: $1"
    help
    ;;
esac