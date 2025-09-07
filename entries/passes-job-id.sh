#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

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

test -e "${name}.fb"
grep " --option=job_id=99999" 'log.txt'
