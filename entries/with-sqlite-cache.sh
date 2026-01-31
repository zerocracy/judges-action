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
  "INPUT_DRY-RUN=false" \
  "INPUT_FAIL-FAST=true" \
  "INPUT_GITHUB-TOKEN=test-token" \
  "INPUT_SQLITE-CACHE=cache-file.sqlite" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=true" \
  "INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000"

factbase_exists "${name}"
file_exists \
  "cache-file.sqlite" \
  "This indicates the INPUT_SQLITE-CACHE parameter is not working correctly"
