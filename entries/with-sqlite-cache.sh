#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -ex -o pipefail

SELF=$1

BUNDLE_GEMFILE="${SELF}/Gemfile"
export BUNDLE_GEMFILE
bundle exec judges eval test.fb "\$fb.insert" > /dev/null

env "GITHUB_WORKSPACE=$(pwd)" \
  'INPUT_DRY-RUN=false' \
  'INPUT_FAIL-FAST=true' \
  'INPUT_GITHUB-TOKEN=test-token' \
  'INPUT_SQLITE-CACHE=cache-file.sqlite' \
  'INPUT_FACTBASE=test.fb' \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=true' \
  'INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt

[ -e test.fb ]
[ -e cache-file.sqlite ]
