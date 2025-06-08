#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -ex -o pipefail

SELF=$1

name=$(LC_ALL=C tr -dc '[:lower:]' </dev/urandom | head -c 16 || true)

BUNDLE_GEMFILE="${SELF}/Gemfile"
export BUNDLE_GEMFILE
bundle exec judges eval "${name}.fb" "\$fb.insert" > /dev/null

(env "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_FAIL-FAST=true' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  'INPUT_VERBOSE=false' \
  'INPUT_GITHUB-TOKEN=barfoo' \
  'INPUT_TOKEN=ZRCY-00000000-0000-0000-0000-000000000000' \
  "${SELF}/entry.sh" 2>&1 || true) | tee log.txt

test -e "${name}.fb"
grep '(#0) at judges' log.txt
grep 'in --fail-fast mode' log.txt
