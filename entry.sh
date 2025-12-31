#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

start=$(date +%s)

VERSION=0.0.0

echo "The 'judges-action' ${VERSION} is running"

if [ "${SKIP_VERSION_CHECKING}" != 'true' ]; then
    set +e
    set +o pipefail
    resp=$(curl --silent -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/zerocracy/judges-action/releases/latest)
    latest=$(echo "$resp" | jq -r '.tag_name' 2>/dev/null)
    rc=$?
    set -e -o pipefail
    if [ "$rc" -ne 0 ] || [ -z "${latest}" ] || [ "${latest}" == "null" ]; then
        echo "!!! Could not fetch the latest version from GitHub."
        echo "!!! GitHub returned:"
        echo "$resp"
        echo "!!! Disabling version checking for the rest of the script."
        SKIP_VERSION_CHECKING=true
    elif [ "${latest}" != "${VERSION}" ]; then
        echo "!!! The latest version of the judges-action plugin available in"
        echo "!!! its GitHub repository is ${latest}: https://github.com/zerocracy/judges-action."
        echo "!!! However, you are using a different version: ${VERSION}."
        echo "!!! This will most likely lead to runtime issues and maybe even data corruption."
        echo "!!! It is strongly advised to upgrade."
    fi
fi

if [ "${INPUT_VERBOSE}" == 'true' ]; then
    set -x
fi

if [ -z "$1" ]; then
    SELF=$(dirname "$0")
else
    SELF=$1
fi

if [ -z "${JUDGES}" ]; then
    BUNDLE_GEMFILE="${SELF}/Gemfile"
    export BUNDLE_GEMFILE
    JUDGES='bundle exec judges'
fi

${JUDGES} --version

if [ -z "${GITHUB_WORKSPACE}" ]; then
    echo 'Probably you are running this Docker image not from GitHub Actions.'
    echo 'In order to do it right, do this:'
    echo '  docker build . -t judges-action'
    echo '  docker run -it --rm --entrypoint /bin/bash judges-action'
    exit 1
fi

name="$(basename "${INPUT_FACTBASE}")"
name="${name%.*}"
fb=$(realpath "$( [[ ${INPUT_FACTBASE} = /* ]] && echo "${INPUT_FACTBASE}" || echo "${GITHUB_WORKSPACE}/${INPUT_FACTBASE}" )")
if [[ ! "${name}" =~ ^[a-z][a-z0-9-]{1,23}$ ]]; then
    echo "The base name (\"${name}\") of the factbase file doesn't match the expected pattern."
    echo "The file name is: \"${INPUT_FACTBASE}\""
    echo "A base name must only include lowercase English letters, numbers, and a dash,"
    echo "may start only with a letter, and may not be longer than 24 characters."
    exit 1
fi

if [ -z "${INPUT_TOKEN}" ]; then
    echo "The 'token' plugin parameter is not set."
    echo "We stop here, since all further operations will fail anyway."
    echo "By the way, if you want to run it in 'dry' mode,"
    echo "without any connections to the server, use 'dry-run: true'."
    exit 1
fi

export GLI_DEBUG=true

cd "${SELF}"

declare -a gopts=(--echo)
if [ "${INPUT_VERBOSE}" == 'true' ]; then
    gopts+=('--verbose')
else
    echo "Since 'verbose' is not set to 'true', you will not see detailed logs"
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
    options+=("--option=${k}=${v}");
done <<< "${INPUT_OPTIONS}"
if [ -z "${INPUT_REPOSITORIES}" ]; then
    echo "The 'repositories' plugin parameter is not set, using current repository: ${GITHUB_REPOSITORY}"
    options+=("--option=repositories=${GITHUB_REPOSITORY}");
else
    options+=("--option=repositories=${INPUT_REPOSITORIES}");
fi

if [ -n "${GITHUB_RUN_ID}" ]; then
    options+=("--option=job_id=${GITHUB_RUN_ID}")
fi

options+=("--option=action_version=${VERSION}")
options+=("--option=vitals_url=${VITALS_URL}")
if [ "$(printenv "INPUT_FAIL-FAST" || echo 'false')" == 'true' ]; then
    options+=("--fail-fast");
    echo "Since 'fail-fast' is set to 'true', we will stop after the first failure"
else
    echo "Since 'fail-fast' is not set to 'true', we will run all judges even if some of them fail"
fi

${JUDGES} "${gopts[@]}" eval \
    "${fb}" \
    "\$fb.query(\"(eq what 'judges-summary')\").delete!"

if [ "$(printenv "INPUT_DRY-RUN" || echo 'false')" == 'true' ]; then
    ALL_JUDGES=$(mktemp -d)
    options+=("--no-expect-judges")
else
    ALL_JUDGES=${SELF}/judges
fi

github_token_found=false
for opt in "${options[@]}"; do
    if [[ "${opt}" == "--option=github_token="* ]]; then
        github_token_found=true
        break
    fi
done
if [ "${github_token_found}" == "true" ]; then
    echo "The 'github_token' option is set, using it"
fi
if [ "${github_token_found}" == "false" ]; then
    if [ -z "$(printenv "INPUT_GITHUB-TOKEN")" ]; then
        echo "The 'github-token' plugin parameter is not set (\$INPUT_GITHUB-TOKEN is empty)"
    else
        echo "The 'github-token' plugin parameter is set, using it"
        options+=("--option=github_token=$(printenv "INPUT_GITHUB-TOKEN")");
        github_token_found=true
    fi
fi
if [ "${github_token_found}" == "false" ]; then
    echo "You have not provided a GitHub token via the 'github-token' option."
    echo "We stop here because all further processing will most likely fail."
    exit 1
fi

bots_found=false
for opt in "${options[@]}"; do
    if [[ "${opt}" == "--option=bots="* ]]; then
        bots_found=true
        break
    fi
done
if [ "${bots_found}" == "false" ]; then
    if [ -n "$(printenv "INPUT_BOTS")" ]; then
        echo "The 'bots' plugin parameter is set, using it"
        options+=("--option=bots=$(printenv "INPUT_BOTS")");
    fi
fi

cache_min_age=false
for opt in "${options[@]}"; do
    if [[ "${opt}" == "--option=sqlite_cache_min_age="* ]]; then
        cache_min_age=true
        break
    fi
done
if [ "${cache_min_age}" == "false" ]; then
    options+=("--option=sqlite_cache_min_age=3600");
fi

owner="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
if [ "$(printenv "INPUT_DRY-RUN" || echo 'false')" == 'true' ]; then
    echo "We are in 'dry' mode; skipping 'pull'"
else
    ${JUDGES} "${gopts[@]}" pull \
        --timeout=0 \
        "--token=${INPUT_TOKEN}" \
        "--owner=${owner}" \
        "${name}" "${fb}"
fi

sqlite=$(printenv "INPUT_SQLITE-CACHE" || true)
if [ -n "${sqlite}" ]; then
    sqlite=$(realpath "$( [[ ${INPUT_FACTBASE} = /* ]] && echo "${sqlite}" || echo "${GITHUB_WORKSPACE}/${sqlite}" )")
    options+=("--option=sqlite_cache=${sqlite}");
    echo "Using SQLite for HTTP caching: ${sqlite}"
    ${JUDGES} "${gopts[@]}" download \
        "--token=${INPUT_TOKEN}" \
        "--owner=${owner}" \
        "${name}" "${sqlite}"
else
    echo "SQLite is not used for HTTP caching because the sqlite-cache option is not set"
fi

timeout=${INPUT_TIMEOUT}
if [ -z "${timeout}" ]; then
    timeout=10
fi
timeout=$((timeout * 60))
echo "Each judge will spend up to ${timeout} seconds"

lifetime=${INPUT_LIFETIME}
if [ -z "${lifetime}" ]; then
    lifetime=15
fi
lifetime=$((lifetime * 60))
echo "The update will run for up to ${lifetime} seconds"

cycles=${INPUT_CYCLES}
if [ -z "${cycles}" ]; then
    cycles=2
fi
echo "The total number of cycles to run is ${cycles}"

${JUDGES} "${gopts[@]}" --hello update \
    --no-log \
    --quiet \
    --summary=add \
    --shuffle=aaa \
    --boost=github-events \
    --lifetime "${lifetime}" \
    --timeout "${timeout}" \
    --lib "${SELF}/lib" \
    --max-cycles "${cycles}" \
    --statistics \
    --churn=churn.txt \
    "${options[@]}" \
    "${ALL_JUDGES}" \
    "${fb}"

if [ -e "${sqlite}" ]; then
    ${JUDGES} "${gopts[@]}" upload \
        "--token=${INPUT_TOKEN}" \
        "--owner=${owner}" \
        "${name}" "${sqlite}"
else
    echo "SQLite is not used for HTTP caching because the sqlite-cache option is not set"
fi

if [ "${SKIP_VERSION_CHECKING}" != 'true' ]; then
    action_version=$(curl --retry 5 --retry-delay 5 --retry-max-time 40 --connect-timeout 5 -sL https://api.github.com/repos/zerocracy/judges-action/releases/latest | jq -r '.tag_name')
    if [ "${action_version}" == "${VERSION}" ] || [ "${action_version}" == null ]; then
        action_version=${VERSION}
    else
        action_version="${VERSION}!${action_version}"
    fi
else
    action_version=${VERSION}
fi

if [ "$(printenv "INPUT_DRY-RUN" || echo 'false')" == 'true' ]; then
    echo "We are in 'dry' mode; skipping 'push'"
else
    ${JUDGES} "${gopts[@]}" push \
        --no-zip \
        --timeout=0 \
        "--owner=${owner}" \
        "--meta=workflow_url:${owner}" \
        "--meta=churn:$(cat churn.txt)" \
        "--meta=vitals_url:${VITALS_URL}" \
        "--meta=duration:$(($(date +%s) - start))" \
        "--meta=action_version:${action_version}" \
        "--token=${INPUT_TOKEN}" \
        "${name}" "${fb}"
fi
