#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

bundle exec judges eval "${name}.fb" "f = \$fb.insert; f.what = 'judges-summary'; f.cycles = 7"

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN"

factbase_exists "${name}"
