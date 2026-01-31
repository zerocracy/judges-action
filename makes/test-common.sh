#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Common test helpers for judges-action integration tests
# Provides reusable functions to reduce code duplication across test scripts

# Run the entry script with given environment variables and capture output
# Usage: run_entry_script <self> <expected_result> <env_var1> <env_var2> ...
# where self is the path to the script directory (usually $SELF)
# and expected_result is either "success" or "failure"
run_entry_script() {
    local self=$1
    local expected_result=$2
    shift 2

    set +e
    env "$@" "${self}/entry.sh" 2>&1 | tee log.txt
    local exit_code=$?
    set -e

    if [ "$expected_result" = "success" ]; then
        if [ $exit_code -ne 0 ]; then
            die "judges-action script failed with exit code $exit_code, but should succeed" \
              "Check log.txt for details of the failure"
        fi
    elif [ "$expected_result" = "failure" ]; then
        if [ $exit_code -eq 0 ]; then
            die "judges-action script succeeded when it should have failed" \
              "Expected: script to exit with non-zero code"
        fi
    fi
}

# Check that a factbase file was created
# Usage: factbase_exists <name> [error_message]
factbase_exists() {
    local name=$1
    test -e "${name}.fb" || die "Expected factbase file '${name}.fb' was not created" "${2:-}"
}

# Check that a pattern exists in the log
# Usage: log_contains <pattern> [error_message]
log_contains() {
    local pattern=$1
    grep -qF "$pattern" log.txt || die "Expected pattern '$pattern' not found in log.txt" "${2:-}"
}

# Check that a pattern does NOT exist in the log
# Usage: log_not_contains <pattern> [error_message]
log_not_contains() {
    local pattern=$1
    if grep -qF "$pattern" log.txt; then
        die "Unexpected pattern '$pattern' found in log.txt" "${2:-}"
    fi
}

# Check that a file exists
# Usage: file_exists <filename> [error_message]
file_exists() {
    local file=$1
    test -e "${file}" || die "Expected file '$file' was not created" "${2:-}"
}

# Exit with formatted error message
# Usage: die <message1> [message2] [message3] ...
# Outputs all messages to stderr with "ERROR:" prefix and exits with code 1
die() {
    for msg in "$@"; do
        echo "ERROR: $msg" >&2
    done
    exit 1
}
