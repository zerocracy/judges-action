#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

opts=$(cat << 'EOF'
  x99=it's a\path
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
  "INPUT_GITHUB-TOKEN=THETOKEN"

log_contains \
  " --option=x99=it's a\path" \
  "This indicates quotes and backslashes in option values are mangled by the entry script"
