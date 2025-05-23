#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

testScansOneRepo() {
  tmp=target/shunit2/scans-one-repo
  mkdir -p "${tmp}"
  GITHUB_WORKSPACE=${tmp}
  export GITHUB_WORKSPACE
  INPUT_VERBOSE=false
  export INPUT_VERBOSE
  INPUT_REPOSITORIES=yegor256/factbase
  export INPUT_REPOSITORIES
  INPUT_DRY_RUN=true
  export INPUT_DRY_RUN
  INPUT_CYCLES=1
  export INPUT_CYCLES
  INPUT_FACTBASE=test.fb
  export INPUT_FACTBASE
  INPUT_GITHUB_TOKEN=test-token
  export INPUT_GITHUB_TOKEN
  bundle exec judges eval "${tmp}/test.fb" "\$fb.insert" > /dev/null
  ./entry.sh > "${tmp}/log.txt" 2>&1
  assertTrue "[ -e '${tmp}/test.fb' ]"
}

testPassesGithubToken() {
  tmp=target/shunit2/passes-github-token
  mkdir -p "${tmp}"
  GITHUB_WORKSPACE=${tmp}
  export GITHUB_WORKSPACE
  INPUT_VERBOSE=false
  export INPUT_VERBOSE
  INPUT_DRY_RUN=true
  export INPUT_DRY_RUN
  INPUT_FACTBASE=test.fb
  export INPUT_FACTBASE
  INPUT_REPOSITORIES=yegor256/factbase
  export INPUT_REPOSITORIES
  INPUT_CYCLES=1
  export INPUT_CYCLES
  INPUT_GITHUB_TOKEN=THETOKEN
  export INPUT_GITHUB_TOKEN
  bundle exec judges eval "${tmp}/test.fb" "\$fb.insert" > /dev/null
  ./entry.sh > "${tmp}/log.txt" 2>&1
  assertTrue "grep github_token=THETOKEN '${tmp}/log.txt'"
}

testDoesntUseDefaultGithubToken() {
  tmp=target/shunit2/uses-default-github-token
  mkdir -p "${tmp}"
  GITHUB_WORKSPACE=${tmp}
  export GITHUB_WORKSPACE
  INPUT_VERBOSE=false
  export INPUT_VERBOSE
  INPUT_DRY_RUN=true
  export INPUT_DRY_RUN
  INPUT_FACTBASE=test.fb
  export INPUT_FACTBASE
  INPUT_REPOSITORIES=yegor256/factbase
  export INPUT_REPOSITORIES
  INPUT_CYCLES=1
  export INPUT_CYCLES
  INPUT_GITHUB_TOKEN=explicit-token
  export INPUT_GITHUB_TOKEN
  GITHUB_TOKEN=NEVERTOKEN
  export GITHUB_TOKEN
  bundle exec judges eval "${tmp}/test.fb" "\$fb.insert" > /dev/null
  ./entry.sh > "${tmp}/log.txt" 2>&1
  assertTrue "grep github_token=explicit-token '${tmp}/log.txt'"
  assertTrue "grep -v github_token=NEVERTOKEN '${tmp}/log.txt'"
}

testFailsWithoutGithubToken() {
  tmp=target/shunit2/fails-without-github-token
  mkdir -p "${tmp}"
  GITHUB_WORKSPACE=${tmp}
  export GITHUB_WORKSPACE
  INPUT_VERBOSE=false
  export INPUT_VERBOSE
  INPUT_DRY_RUN=true
  export INPUT_DRY_RUN
  INPUT_FACTBASE=test.fb
  export INPUT_FACTBASE
  INPUT_REPOSITORIES=yegor256/factbase
  export INPUT_REPOSITORIES
  INPUT_CYCLES=1
  export INPUT_CYCLES
  INPUT_GITHUB_TOKEN=
  export INPUT_GITHUB_TOKEN
  bundle exec judges eval "${tmp}/test.fb" "\$fb.insert" > /dev/null
  ./entry.sh > "${tmp}/log.txt" 2>&1 || true
  assertTrue "grep 'We stop here' '${tmp}/log.txt'"
}
