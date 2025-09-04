#!/usr/bin/env bash
set -euo pipefail
export INPUT_VERBOSE="true"
echo "${INPUT_VERBOSE}"
./pure_bash_coverage/generate_coverage_report.sh ../entry.sh
