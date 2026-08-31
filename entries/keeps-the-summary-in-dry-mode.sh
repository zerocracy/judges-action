#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

bundle exec judges eval "${name}.fb" "f = \$fb.insert; f.what = 'judges-summary'; f.cycles = 7"
before=$(cksum < "${name}.fb")

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN"

kept=$(bundle exec ruby -e "require 'factbase'; f = Factbase.new; f.import(File.binread(ARGV[0])); puts f.query(\"(and (eq what 'judges-summary') (eq cycles 7))\").each.to_a.size" "${name}.fb")
test "${kept}" = '1' || die "A dry run must keep the judges-summary facts of the factbase it was given, found ${kept} of them"
test "$(cksum < "${name}.fb")" = "${before}" || die "A dry run must leave the factbase exactly as it found it"
