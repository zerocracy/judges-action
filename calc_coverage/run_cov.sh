#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT
set -euo pipefail
export INPUT_VERBOSE="true"
echo "${INPUT_VERBOSE}"
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
"${DIR}/pure_bash_coverage/generate_coverage_report.sh" "${DIR}/../entry.sh"

