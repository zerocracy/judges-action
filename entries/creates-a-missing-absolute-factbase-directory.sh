#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_REPOSITORY=zerocracy/judges-action" \
  "GITHUB_REPOSITORY_OWNER=zerocracy" \
  "GITHUB_SERVER_URL=https://github.com" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=test-token" \
  "INPUT_FACTBASE=$(pwd)/${name}/${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_TOKEN=something"

file_exists "$(pwd)/${name}/${name}.fb" \
  "The factbase was not created inside a missing directory given by an absolute path"
