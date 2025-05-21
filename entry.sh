#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e
set -x
set -o pipefail

start=$(date +%s)

VERSION=0.0.0

if [ -z "${JUDGES}" ]; then
    JUDGES=judges
fi

if [ -z "$1" ]; then
    SELF=$(pwd)
else
    SELF=$1
fi

if [ -z "${GITHUB_WORKSPACE}" ]; then
    echo 'Probably you are running this Docker image not from GitHub Actions.'
    echo 'In order to do it right, do this:'
    echo '  docker build . -t judges-action'
    echo '  docker run -it --rm --entrypoint /bin/bash judges-action'
    exit 1
fi

if [ -z "${INPUT_CYCLES}" ]; then
    echo 'The INPUT_CYCLES environment variable is not specified, but it should be.'
    exit 1
fi

if [ -z "${INPUT_REPOSITORIES}" ]; then
    echo 'The INPUT_REPOSITORIES environment variable is not specified, but it should be.'
    exit 1
fi

name="$(basename "${INPUT_FACTBASE}")"
name="${name%.*}"
if [[ ! "${name}" =~ ^[a-z][a-z0-9-]{1,23}$ ]]; then
    echo "The base name (\"${name}\") of the factbase file doesn't match the expected pattern."
    echo "The file name is: \"${INPUT_FACTBASE}\""
    echo "A base name must only include low-case English letters, numbers, and a dash,"
    echo "may start only with a letter, and may not be longer than 24 characters."
    exit 1
fi

export GLI_DEBUG=true

fb=$(realpath "${INPUT_FACTBASE}")

declare -a gopts=()
if [ "${INPUT_VERBOSE}" == 'true' ]; then
    gopts+=('--verbose')
fi

owner="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

cd "${GITHUB_WORKSPACE}"

if [ -n "${INPUT_TOKEN}" ]; then
    ${JUDGES} "${gopts[@]}" pull \
        --timeout=0 \
        "--token=${INPUT_TOKEN}" \
        "--owner=${owner}" \
        "${name}" "${fb}"
fi

GITHUB_REPO_NAME="${GITHUB_REPOSITORY#"${GITHUB_REPOSITORY_OWNER}/"}"
VITALS_URL="https://${GITHUB_REPOSITORY_OWNER}.github.io/${GITHUB_REPO_NAME}/${name}-vitals.html"

declare -a options=()
while IFS= read -r o; do
    s=$(echo "${o}" | xargs)
    if [ "${s}" = "" ]; then
        continue
    fi
    k=$(echo "${s} "| cut -f1 -d '=')
    v=$(echo "${s}" | cut -f2- -d '=')
    if [[ "${k}" == vitals_url ]]; then
        VITALS_URL="${v}"
        continue
    fi
done <<< "${INPUT_OPTIONS}"
if [ -n "${INPUT_REPOSITORIES}" ]; then
    options+=("--option=repositories=${INPUT_REPOSITORIES}");
fi
if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    options+=("--option=github_token=${INPUT_GITHUB_TOKEN}");
fi
options+=("--option=judges_action_version=${VERSION}")
options+=("--option=vitals_url=${VITALS_URL}")
if [ -n "${INPUT_FAIL_FAST}" ]; then
    options+=("--fail-fast");
fi

echo "The 'judges-action' ${VERSION} is running"

cd "${SELF}"
${JUDGES} "${gopts[@]}" eval \
    "${fb}" \
    "\$fb.query(\"(eq what 'judges-summary')\").delete!"

${JUDGES} "${gopts[@]}" update \
    --no-log \
    --quiet \
    --summary \
    --shuffle=aaa \
    --boost=github-events \
    --timeout=180 \
    --lib "${SELF}/lib" \
    --max-cycles "${INPUT_CYCLES}" \
    "${options[@]}" \
    "${SELF}/judges" \
    "${fb}"

action_version=$(curl --retry 5 --retry-delay 5 --retry-max-time 40 --connect-timeout 5 -sL https://api.github.com/repos/zerocracy/judges-action/releases/latest | jq -r '.tag_name')
if [ "$action_version" = "$VERSION" ]; then
    action_version=$VERSION
else
    action_version="${VERSION}!${action_version}"
fi

if [ -n "${INPUT_TOKEN}" ]; then
    ${JUDGES} "${gopts[@]}" push \
        --no-zip \
        --timeout=0 \
        "--owner=${owner}" \
        "--meta=workflow_url:${owner}" \
        "--meta=vitals_url:${VITALS_URL}" \
        "--meta=duration:$(($(date +%s) - start))" \
        "--meta=action_version:${action_version}" \
        "--token=${INPUT_TOKEN}" \
        "${name}" "${fb}"
fi
