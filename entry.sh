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

VERSION=0.0.0

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

name=$(basename "${INPUT_FACTBASE}")
name=${name%.*}
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
if [ -n "${INPUT_VERBOSE}" ]; then
    gopts+=("--verbose")
fi

owner="${INPUT_OWNER} $(hostname)"

if [ -n "${INPUT_TOKEN}" ]; then
    bundle exec judges "${gopts[@]}" pull \
        "--token=${INPUT_TOKEN}" \
        "--owner=${owner}" \
        "${name}" "${fb}"
fi

if [ -n "${INPUT_TRIM}" ]; then
    if [ -e "${fb}" ]; then
        # Remove facts that are too old
        time=$(ruby -e "require 'time'; puts (Time.now - ${INPUT_TRIM} * 24 * 60 * 60).utc.iso8601")
        bundle exec judges "${gopts[@]}" trim --query "(lt _time ${time})" "${fb}"
    fi
fi

# Add new facts, using the judges (Ruby scripts) in the /judges directory
declare -a options=()
while IFS= read -r o; do
    v=$(echo "${o}" | xargs)
    if [ "${v}" = "" ]; then continue; fi
    options+=("--option=${v}")
done <<< "${INPUT_OPTIONS}"
options+=("--option=judges_action_version=${VERSION}")

echo "The 'judges-action' ${VERSION} is running"

cd "${SELF}"
bundle exec judges "${gopts[@]}" update \
    --no-log \
    --quiet \
    --summary \
    --lib "${SELF}/lib" \
    --max-cycles "${INPUT_CYCLES}" \
    "${options[@]}" \
    "${SELF}/judges" \
    "${fb}"

if [ -n "${INPUT_TOKEN}" ]; then
    bundle exec judges "${gopts[@]}" push \
        "--owner=${owner}" \
        "--token=${INPUT_TOKEN}" \
        "${name}" "${fb}"
fi
