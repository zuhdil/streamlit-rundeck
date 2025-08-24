#!/bin/bash

# Map Rundeck options to environment variables if needed
GITHUB_URL="${GITHUB_URL:-${RD_OPTION_GITHUB_URL}}"
MAIN_FILE="${MAIN_FILE:-${RD_OPTION_MAIN_FILE}}"
APP_NAME="${APP_NAME:-${RD_OPTION_APP_NAME}}"
TARGET_BRANCH="${TARGET_BRANCH:-${RD_OPTION_TARGET_BRANCH}}"

echo "=== DEBUG: Rundeck Options ==="
echo "RD_OPTION_GITHUB_URL: '$RD_OPTION_GITHUB_URL'"
echo "RD_OPTION_MAIN_FILE: '$RD_OPTION_MAIN_FILE'"
echo "RD_OPTION_APP_NAME: '$RD_OPTION_APP_NAME'"
echo "RD_OPTION_TARGET_BRANCH: '$RD_OPTION_TARGET_BRANCH'"

echo "=== DEBUG: Mapped Environment Variables ==="
echo "GITHUB_URL: '$GITHUB_URL'"
echo "MAIN_FILE: '$MAIN_FILE'"
echo "APP_NAME: '$APP_NAME'"
echo "TARGET_BRANCH: '$TARGET_BRANCH'"
echo "PROJECT_ID: '$PROJECT_ID'"
echo "ARTIFACT_REGISTRY: '$ARTIFACT_REGISTRY'"

echo "=== DEBUG: All Environment Variables ==="
env | sort

echo "=== DEBUG: File Upload Investigation ==="
echo "RD_OPTION_SECRETS_FILE: '${RD_OPTION_SECRETS_FILE:-UNSET}'"
if [[ -n "${RD_OPTION_SECRETS_FILE:-}" ]]; then
    echo "Secrets file path exists: ${RD_OPTION_SECRETS_FILE}"
    echo "File exists check: $(test -f "${RD_OPTION_SECRETS_FILE}" && echo "YES" || echo "NO")"
    if [[ -f "${RD_OPTION_SECRETS_FILE}" ]]; then
        echo "File size: $(wc -c < "${RD_OPTION_SECRETS_FILE}") bytes"
        echo "File permissions: $(ls -la "${RD_OPTION_SECRETS_FILE}")"
        echo "First 5 lines of file:"
        head -n 5 "${RD_OPTION_SECRETS_FILE}" || echo "Could not read file"
    fi
else
    echo "No secrets file uploaded or RD_OPTION_SECRETS_FILE not set"
fi

echo "=== DEBUG: Validating Required Variables ==="
if [[ -z "$GITHUB_URL" ]]; then
    echo "ERROR: GITHUB_URL is empty or unset"
else
    echo "OK: GITHUB_URL is set"
fi

if [[ -z "$MAIN_FILE" ]]; then
    echo "ERROR: MAIN_FILE is empty or unset"
else
    echo "OK: MAIN_FILE is set"
fi

if [[ -z "$APP_NAME" ]]; then
    echo "ERROR: APP_NAME is empty or unset"
else
    echo "OK: APP_NAME is set"
fi

if [[ -z "$PROJECT_ID" ]]; then
    echo "ERROR: PROJECT_ID is empty or unset"
else
    echo "OK: PROJECT_ID is set"
fi

if [[ -z "$ARTIFACT_REGISTRY" ]]; then
    echo "ERROR: ARTIFACT_REGISTRY is empty or unset"
else
    echo "OK: ARTIFACT_REGISTRY is set"
fi