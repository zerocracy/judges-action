#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

set -ex -o pipefail

SELF=$1

GITHUB_WORKSPACE=$(pwd)
export GITHUB_WORKSPACE
INPUT_TOKEN=something
export INPUT_TOKEN
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

bundle exec judges eval test.fb "\$fb.insert" > /dev/null

"${SELF}/entry.sh" 2>&1 | tee log.txt

[ -e 'test.fb' ]
