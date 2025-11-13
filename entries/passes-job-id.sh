#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

set +e
env "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_RUN_ID=99999" \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=false' \
  'INPUT_TOKEN=something' \
  'INPUT_DRY-RUN=true' \
  'INPUT_GITHUB-TOKEN=THETOKEN' \
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

grep " --option=job_id=99999" 'log.txt' || {
    echo "ERROR: Expected job_id option not found in log.txt" >&2
    echo "Expected: ' --option=job_id=99999'" >&2
    echo "This indicates the GITHUB_RUN_ID environment variable is not being processed as job_id" >&2
    exit 1
}
