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
  INPUT_CYCLES=1
  export INPUT_CYCLES
  INPUT_FACTBASE=test.fb
  export INPUT_FACTBASE
  bundle exec judges eval "${tmp}/test.fb" "\$fb.insert" > /dev/null
  ./entry.sh 2>&1 | tee "${tmp}/log.txt"
}

testPassesGithubToken() {
  tmp=target/shunit2/passes-github-token
  mkdir -p "${tmp}"
  GITHUB_WORKSPACE=${tmp}
  export GITHUB_WORKSPACE
  INPUT_VERBOSE=false
  export INPUT_VERBOSE
  INPUT_FACTBASE=test.fb
  export INPUT_FACTBASE
  INPUT_REPOSITORIES=yegor256/factbase
  export INPUT_REPOSITORIES
  INPUT_CYCLES=1
  export INPUT_CYCLES
  INPUT_GITHUB_TOKEN=THETOKEN
  export INPUT_GITHUB_TOKEN
  bundle exec judges eval "${tmp}/test.fb" "\$fb.insert" > /dev/null
  ./entry.sh 2>&1 | tee "${tmp}/log.txt"
  assertTrue "grep github_token=THETOKEN '${tmp}/log.txt'"
}
