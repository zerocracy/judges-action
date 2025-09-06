#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
setup_test_env "${SELF}" name

opts=$(cat << 'EOF'
  foo42=bar
  foo4444=bar
  x88=hello world!
EOF
)

env "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  'INPUT_CYCLES=1' \
  'INPUT_REPOSITORIES=yegor256/factbase' \
  "INPUT_OPTIONS=${opts}" \
  'INPUT_VERBOSE=false' \
  'INPUT_TOKEN=something' \
  'INPUT_DRY-RUN=true' \
  'INPUT_GITHUB-TOKEN=THETOKEN' \
  "${SELF}/entry.sh" 2>&1 | tee log.txt

test -e "${name}.fb"
grep " --option=foo42=bar" 'log.txt'
grep " --option=foo4444=bar" 'log.txt'
grep " --option=x88=hello world!" 'log.txt'
