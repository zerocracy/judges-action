#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e
set +o pipefail
source "$1/makes/test-common.sh"

scratch=$(mktemp -d)
trap 'rm -rf "${scratch}"' EXIT
cd "${scratch}"
mkdir fixture
printf '%s\n' '#!/usr/bin/env bash' 'echo entry-ran' 'exit 23' > fixture/entry.sh
chmod +x fixture/entry.sh
if (run_entry_script "$PWD/fixture" success); then
    die 'A failing entry was reported as successful'
fi
run_entry_script "$PWD/fixture" failure
log_contains entry-ran
