#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

img=$1

(
    echo 'testing=yes'
    echo 'repositories=yegor256/judges'
    echo 'max_events=3'
) > target/opts.txt

# Generate random name, ignoring SIGPIPE errors from tr when head closes the pipe
name=$(LC_ALL=C tr -dc '[:lower:]' </dev/urandom 2>/dev/null | head -c 16) || true

if [ -z "${name}" ]; then
    echo "Failed to generate random name" >&2
    exit 1
fi

docker run --rm \
    -e "SKIP_VERSION_CHECKING=true" \
    -e "GITHUB_WORKSPACE=/tmp" \
    -e "GITHUB_REPOSITORY=zerocracy/judges-action" \
    -e "GITHUB_REPOSITORY_OWNER=zerocracy" \
    -e "GITHUB_SERVER_URL=https://github.com" \
    -e "GITHUB_RUN_ID=0000" \
    -e "INPUT_FACTBASE=/tmp/${name}.fb" \
    -e "INPUT_CYCLES=2" \
    -e "INPUT_VERBOSE=true" \
    -e "INPUT_PAGES=pages" \
    -e "INPUT_FAIL-FAST=true" \
    -e "INPUT_REPOSITORIES=zerocracy/judges-action" \
    -e "INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000" \
    -e "INPUT_GITHUB-TOKEN=00000000-0000-0000-0000-000000000000" \
    -e "INPUT_OPTIONS=$(cat target/opts.txt)" \
    "${img}"
