#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

set +e
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
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo "ERROR: judges-action script failed with exit code $exit_code, but should succeed" >&2
    echo "Check log.txt for details of the failure" >&2
    exit 1
fi

test -e "${name}.fb" || {
    echo "ERROR: Expected factbase file '${name}.fb' was not created" >&2
    exit 1
}

grep "The 'repositories' plugin parameter is not set, using current repository: zerocracy/judges-action" 'log.txt' || {
    echo "ERROR: Expected message about defaulting to current repository not found in log.txt" >&2
    echo "Expected: 'The 'repositories' plugin parameter is not set, using current repository: zerocracy/judges-action'" >&2
    exit 1
}

grep " --option=repositories=zerocracy/judges-action" 'log.txt' || {
    echo "ERROR: Expected judges command with repositories option not found in log.txt" >&2
    echo "Expected: ' --option=repositories=zerocracy/judges-action'" >&2
    echo "This indicates the default repository logic is not working correctly" >&2
    exit 1
}
