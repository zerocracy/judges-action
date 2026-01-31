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
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_FAIL-FAST=true" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_GITHUB-TOKEN=barfoo" \
  "INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000"

factbase_exists "${name}"
log_contains \
  "(#0) at judges" \
  "This indicates judges were not executed as expected"
log_contains \
  "in --fail-fast mode" \
  "This indicates fail-fast behavior was not triggered as expected"
