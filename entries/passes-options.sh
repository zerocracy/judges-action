#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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
  repositories=yegor256/judges
EOF
)

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_REPOSITORY=zerocracy/judges-action" \
  "GITHUB_REPOSITORY_OWNER=zerocracy" \
  "GITHUB_SERVER_URL=https://github.com" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=" \
  "INPUT_OPTIONS=${opts}" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN" \
  "SKIP_VERSION_CHECKING=true" \
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
log_contains \
  " --option=repositories=yegor256/judges" \
  "This indicates repositories from INPUT_OPTIONS are not being passed"
log_not_contains \
  " --option=repositories=zerocracy/judges-action" \
  "This indicates the current repository overrides INPUT_OPTIONS"
log_not_contains \
  "The 'repositories' plugin parameter is not set" \
  "This indicates INPUT_OPTIONS repositories are not detected"

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_REPOSITORY=zerocracy/judges-action" \
  "GITHUB_REPOSITORY_OWNER=zerocracy" \
  "GITHUB_SERVER_URL=https://github.com" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_OPTIONS=${opts}" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN" \
  "SKIP_VERSION_CHECKING=true" \
  "INPUT_BOTS=test-bot,another-bot"

log_contains \
  " --option=repositories=yegor256/judges" \
  "This indicates repositories from INPUT_OPTIONS do not override the dedicated input"
log_not_contains \
  " --option=repositories=yegor256/factbase" \
  "This indicates the dedicated repositories input overrides INPUT_OPTIONS"
