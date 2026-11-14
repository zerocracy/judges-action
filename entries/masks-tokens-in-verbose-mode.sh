#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Verifies that entry.sh emits GitHub Actions ::add-mask:: workflow commands
# for both INPUT_GITHUB-TOKEN and INPUT_TOKEN. Without these commands, bash
# tracing under INPUT_VERBOSE=true would leak the token values into public CI
# logs (the trace prints "+ options+=(--option=github_token=ghp_...)" verbatim).

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

# Distinctive token values so we can match them by exact string.
github_token='ghp_test-secret-github-token-aaaaaaaaaaaa'
zerocracy_token='ZRCY-test-secret-zerocracy-token-bbbbbbbbbbbb'

# Exercise pull and push without sending requests to GitHub or Zerocracy.
cat > judges-stub.sh <<'BASH'
#!/usr/bin/env bash
for arg in "$@"; do
  case "${arg}" in
    --churn=*) printf '0i/0d/0a' > "${arg#--churn=}" ;;
  esac
done
BASH
chmod +x judges-stub.sh

run_entry_script "${SELF}" success \
  "JUDGES=$(pwd)/judges-stub.sh" \
  "SKIP_VERSION_CHECKING=true" \
  "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_REPOSITORY=zerocracy/judges-action" \
  "GITHUB_REPOSITORY_OWNER=zerocracy" \
  "GITHUB_SERVER_URL=https://github.com" \
  "GITHUB_RUN_ID=" \
  "INPUT_DRY-RUN=false" \
  "INPUT_GITHUB-TOKEN=${github_token}" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_VERBOSE=true" \
  "INPUT_TOKEN=${zerocracy_token}"

log_contains "::add-mask::${github_token}" \
  "::add-mask:: workflow command for INPUT_GITHUB-TOKEN must be emitted before bash tracing"
log_contains "::add-mask::${zerocracy_token}" \
  "::add-mask:: workflow command for INPUT_TOKEN must be emitted before bash tracing"
log_precedes "::add-mask::${github_token}" "--option=github_token=${github_token}" \
  "github_token reached the bash trace before ::add-mask:: was emitted"
log_contains "--token=${zerocracy_token}" \
  "the non-dry invocation must actually trace the Zerocracy token argument"
log_precedes "::add-mask::${zerocracy_token}" "--token=${zerocracy_token}" \
  "zerocracy_token reached the bash trace before ::add-mask:: was emitted"
