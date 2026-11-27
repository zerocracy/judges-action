#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail
source "$1/makes/test-common.sh"

scratch=$(mktemp -d)
trap 'rm -rf "${scratch}"' EXIT
cd "${scratch}"
if (log_not_contains unexpected); then
    die 'A missing log cannot prove the pattern was absent'
fi
printf '%s\n' 'ordinary output' > log.txt
log_not_contains unexpected
printf '%s\n' 'unexpected' >> log.txt
if (log_not_contains unexpected); then
    die 'The negative assertion missed a matching line'
fi
