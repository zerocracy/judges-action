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
rm -f "${bin}/calls.txt"
cat > "${bin}/curl" << 'EOF'
#!/usr/bin/env bash
calls="$(dirname "$0")/calls.txt"
seen=$(cat "${calls}" 2>/dev/null || echo 0)
echo $((seen + 1)) > "${calls}"
if [ "${seen}" -eq 0 ]; then
    echo '{"tag_name":"0.0.0"}'
    exit 0
fi
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
  "INPUT_GITHUB-TOKEN=THETOKEN" \
  "SKIP_VERSION_CHECKING=false" \
  "GITHUB_RUN_ID="

factbase_exists "${name}"
test "$(cat "${bin}/calls.txt" 2>/dev/null)" = '2' || die \
  "Both version checks must call curl, but found $(cat "${bin}/calls.txt" 2>/dev/null || echo 0) calls"
log_not_contains \
  "Could not fetch the latest version from GitHub." \
  "The initial version check must succeed so the push-time version check is reached"
log_contains \
  "skipping 'push'" \
  "A version check that cannot reach GitHub must not throw away a cycle that is ready to be pushed"
