#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

base=$(realpath "$(dirname "$0")/..")

mkdir -p "${base}/target/entries-logs"

run_test() {
    local sh="$1"
    local fqn="${base}/entries/${sh}"
    if [ ! -x "${fqn}" ]; then
        echo "The file is not executable: ${fqn}"
        exit 1
    fi
    mkdir -p "${base}/target/${sh}"
    if /bin/bash -c "cd \"target/${sh}\" && exec \"${fqn}\" \"${base}\" > \"${base}/target/entries-logs/${sh}.txt\" 2>&1"; then
        echo "👍🏻 ${sh} passed"
        return 0
    else
        cat "${base}/target/entries-logs/${sh}.txt"
        echo "❌ ${sh} failed"
        return 1
    fi
}

export -f run_test
export base

find "${base}/entries" -name '*.sh' -exec basename {} \; | \
    parallel --halt now,fail=1 --line-buffer run_test
