#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -ex -o pipefail

SELF=$1

bundle exec judges eval test.fb "\$fb.insert" > /dev/null

env "GITHUB_WORKSPACE=$(pwd)" \
  'INPUT_FACTBASE=test.fb' \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=false' \
  'INPUT_TOKEN=something' \
  'INPUT_DRY-RUN=true' \
  'INPUT_GITHUB-TOKEN=THETOKEN' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt

grep "The 'github-token' plugin parameter is set" 'log.txt'
