#!/bin/bash
# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e
set -x
set -o pipefail

start=$(date +%s)

VERSION=0.0.61

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

# Set URL of the published pages:
GITHUB_REPO_NAME="${GITHUB_REPOSITORY#"${GITHUB_REPOSITORY_OWNER}/"}"
VITALS_URL="https://${GITHUB_REPOSITORY_OWNER}.github.io/${GITHUB_REPO_NAME}/${name}-vitals.html"

# Add new facts, using the judges (Ruby scripts) in the /judges directory
declare -A optionmap=(
    ["repositories"]="${INPUT_REPOSITORIES}"
    ["github_token"]="${INPUT_GITHUB_TOKEN}"
)
declare -a options=()
while IFS= read -r o; do
    s=$(echo "${o}" | xargs)
    if [ "${s}" = "" ]; then continue; fi
    k=$(echo "${s} "| cut -f1 -d '=')
    v=$(echo "${s}" | cut -f2- -d '=')
    if [[ "${k}" == vitals_url ]]; then
        VITALS_URL="${v}"
        continue
    fi
    optionmap[$k]=$v
done <<< "${INPUT_OPTIONS}"
for k in "${!optionmap[@]}"; do
    if [ -n "${optionmap[$k]}" ]; then
        options+=("--option=${k}=${optionmap[$k]}");
    fi
done
options+=("--option=judges_action_version=${VERSION}")
options+=("--option=vitals_url=${VITALS_URL}")

echo "The 'judges-action' ${VERSION} is running"

cd "${SELF}"
${JUDGES} "${gopts[@]}" update \
    --no-log \
    --quiet \
    --summary \
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
