#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

set +e
env "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_FAIL-FAST=true' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=false' \
  'INPUT_GITHUB-TOKEN=barfoo' \
  'INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo "ERROR: judges-action script failed with exit code $exit_code, but should succeed with --quiet flag enabled" >&2
    echo "Check log.txt for details of the failure" >&2
    exit 1
fi

test -e "${name}.fb" || {
    echo "ERROR: Expected factbase file '${name}.fb' was not created" >&2
    exit 1
}

grep '(#0) at judges' log.txt || {
    echo "ERROR: Expected pattern '(#0) at judges' not found in log.txt" >&2
    echo "This indicates judges were not executed as expected" >&2
    exit 1
}

grep 'in --fail-fast mode' log.txt || {
    echo "ERROR: Expected pattern 'in --fail-fast mode' not found in log.txt" >&2
    echo "This indicates fail-fast behavior was not triggered as expected" >&2
    exit 1
}
