#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

opts=$(cat << 'EOF'
  foo42=bar
  foo4444=bar
  x88=hello world!
EOF
)

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_OPTIONS=${opts}" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN" \
  "INPUT_BOTS=test-bot,another-bot"

factbase_exists "${name}"
log_contains \
  " --option=foo42=bar" \
  "This indicates custom options from INPUT_OPTIONS are not being processed correctly"
log_contains \
  " --option=foo4444=bar" \
  "This indicates custom options from INPUT_OPTIONS are not being processed correctly"
log_contains \
  " --option=x88=hello world!" \
  "This indicates custom options with spaces are not being processed correctly"
log_contains \
  " --option=bots=test-bot,another-bot" \
  "This indicates INPUT_BOTS parameter is not being processed correctly"
log_contains \
  " --option=sqlite_cache_min_age=3600" \
  "This indicates sqlite_cache_min_age option with default value is not being processed correctly"
