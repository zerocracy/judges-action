#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Common test helpers for judges-action integration tests
# Provides reusable functions to reduce code duplication across test scripts

# Run the entry script with given environment variables and capture output
# Usage: run_entry_script <expected_result> <env_var1> <env_var2> ...
# where expected_result is either "success" or "failure"
run_entry_script() {
    local expected_result=$1
    shift

    set +e
    env "$@" "${SELF}/entry.sh" 2>&1 | tee log.txt
    local exit_code=$?
    set -e

    if [ "$expected_result" = "success" ]; then
        if [ $exit_code -ne 0 ]; then
            echo "ERROR: judges-action script failed with exit code $exit_code, but should succeed" >&2
            echo "Check log.txt for details of the failure" >&2
            exit 1
        fi
    elif [ "$expected_result" = "failure" ]; then
        if [ $exit_code -eq 0 ]; then
            echo "ERROR: judges-action script succeeded when it should have failed" >&2
            echo "Expected: script to exit with non-zero code" >&2
            exit 1
        fi
    fi
}

# Check that a factbase file was created
# Usage: factbase_exists <name> [error_message]
factbase_exists() {
    local name=$1
    test -e "${name}.fb" || {
        echo "ERROR: Expected factbase file '${name}.fb' was not created" >&2
        if [ -n "${2:-}" ]; then
            echo "ERROR: $2" >&2
        fi
        exit 1
    }
}

# Check that a pattern exists in the log
# Usage: log_contains <pattern> [error_message]
log_contains() {
    local pattern=$1
    grep -F "$pattern" log.txt || {
        echo "ERROR: Expected pattern '$pattern' not found in log.txt" >&2
        if [ -n "${2:-}" ]; then
            echo "ERROR: $2" >&2
        fi
        exit 1
    }
}

# Check that a pattern does NOT exist in the log
# Usage: log_not_contains <pattern> [error_message]
log_not_contains() {
    local pattern=$1
    if grep -qF "$pattern" log.txt; then
        echo "ERROR: Unexpected pattern '$pattern' found in log.txt" >&2
        if [ -n "${2:-}" ]; then
            echo "ERROR: $2" >&2
        fi
        exit 1
    fi
}

# Check that a file exists
# Usage: file_exists <filename> [error_message]
file_exists() {
    local file=$1
    test -e "$file" || {
        echo "ERROR: Expected file '$file' was not created" >&2
        if [ -n "${2:-}" ]; then
            echo "ERROR: $2" >&2
        fi
        exit 1
    }
}
