#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/test-common.sh"

printf -- '--option=github_token=ghp_secret\n' > log.txt

log_contains "--option=github_token=ghp_secret" \
  "log_contains must find a pattern that starts with a dash"

if ( log_not_contains "--option=github_token=ghp_secret" ) 2>/dev/null; then
  echo "ERROR: log_not_contains accepted a pattern that log.txt does contain" >&2
  exit 1
fi

( log_not_contains "--option=github_token=ghp_absent" )

printf -- 'masked --marker-a\ntraced --marker-b\n' > log.txt

log_precedes "--marker-a" "--marker-b" \
  "log_precedes must accept a dashed pattern that comes first"

if ( log_precedes "--marker-b" "--marker-a" ) 2>/dev/null; then
  echo "ERROR: log_precedes accepted a pair that log.txt holds in the other order" >&2
  exit 1
fi

log_precedes "--marker-a" "--marker-absent"   "log_precedes must pass when the second pattern is not in the log at all"
