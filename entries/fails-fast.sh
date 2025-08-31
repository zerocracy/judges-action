#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

SELF=$1

# shellcheck source=../makes/setup-test-env.sh
source "${SELF}/makes/setup-test-env.sh"
name=$(setup_test_env "${SELF}")

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

grep -v 'in --fail-fast mode' log.txt
