#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

bin="$(pwd)/bin"
mkdir -p "${bin}"
cat > "${bin}/curl" << 'EOF'
#!/usr/bin/env bash
exit 7
EOF
chmod +x "${bin}/curl"

run_entry_script "${SELF}" success \
  "PATH=${bin}:${PATH}" \
  "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN"

factbase_exists "${name}"
log_contains \
  "Could not fetch the latest version from GitHub." \
  "A version check that cannot reach GitHub must not end the run before any judge starts"
