#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

env "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_REPOSITORY=zerocracy/judges-action" \
  "GITHUB_REPOSITORY_OWNER=zerocracy" \
  "GITHUB_SERVER_URL=https://github.com" \
  "GITHUB_RUN_ID=12345" \
  'INPUT_DRY-RUN=true' \
  'INPUT_GITHUB-TOKEN=test-token' \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_VERBOSE=true' \
  'INPUT_TOKEN=something' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt

test -e "${name}.fb"

grep "The 'repositories' plugin parameter is not set, using current repository: zerocracy/judges-action" 'log.txt'
grep " --option=repositories=zerocracy/judges-action" 'log.txt'
