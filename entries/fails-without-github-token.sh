#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

set +e
env "GITHUB_WORKSPACE=$(pwd)" \
  'INPUT_DRY-RUN=true' \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=false' \
  'INPUT_TOKEN=something' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "ERROR: judges-action script succeeded when it should have failed due to missing/invalid GitHub token" >&2
    echo "Expected: early exit with 'We stop here' message due to empty INPUT_GITHUB-TOKEN" >&2
    exit 1
fi

test -e "${name}.fb" || {
    echo "ERROR: Expected factbase file '${name}.fb' was not created" >&2
    exit 1
}

grep 'We stop here' log.txt || {
    echo "ERROR: Expected pattern 'We stop here' not found in log.txt" >&2
    echo "This indicates the script did not stop early due to missing GitHub token as expected" >&2
    exit 1
}
