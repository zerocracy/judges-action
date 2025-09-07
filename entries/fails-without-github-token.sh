#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

(env "GITHUB_WORKSPACE=$(pwd)" \
  'INPUT_DRY-RUN=true' \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=false' \
  'INPUT_TOKEN=something' \
  "${SELF}/entry.sh" 2>&1 || true) | tee log.txt

test -e "${name}.fb"
grep 'We stop here' log.txt
