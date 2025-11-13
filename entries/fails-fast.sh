#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

set +e
env "GITHUB_WORKSPACE=$(pwd)" \
  'INPUT_DRY-RUN=false' \
  'INPUT_FAIL-FAST=false' \
  'INPUT_GITHUB-TOKEN=test-token' \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=true' \
  'INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo "ERROR: judges-action script failed with exit code $exit_code, but should succeed with --quiet flag enabled" >&2
    echo "Check log.txt for details of the failure" >&2
    exit 1
fi

grep -v 'in --fail-fast mode' log.txt || {
    echo "ERROR: Unexpected 'in --fail-fast mode' message found in log.txt" >&2
    echo "This script tests with INPUT_FAIL-FAST=false, so fail-fast mode should NOT be active" >&2
    echo "Check that the fail-fast parameter is being processed correctly" >&2
    exit 1
}
