#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

note="earlier step wrote ${name} ünïcödé"
echo "${note}" > step.md

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_STEP_SUMMARY=$(pwd)/step.md" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN"

grep -qF '## zerocracy run' step.md || die "The run report is not published to the step summary at $(pwd)/step.md"
grep -qF "${note}" step.md || die "The step summary at $(pwd)/step.md lost what an earlier step wrote into it"
test ! -e summary.md || die "The run report is left as a stray file at $(pwd)/summary.md"
