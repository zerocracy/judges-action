#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail
source "$1/makes/test-common.sh"

scratch=$(mktemp -d)
trap 'rm -rf "${scratch}"' EXIT
cd "${scratch}"
cp "$1/Makefile" .
touch Dockerfile entry.sh Gemfile Gemfile.lock
mkdir lib judges bin
cat > bin/docker <<'DOCKER'
#!/usr/bin/env bash
set -e -o pipefail
test -d "${!#}"
echo build >> calls.txt
test "$(wc -l < calls.txt)" -eq 1
while [ "$#" -gt 0 ]; do
    if [ "$1" = '--iidfile' ]; then
        printf '%s\n' 'sha256:1234' > "$2"
        break
    fi
    shift
done
DOCKER
chmod +x bin/docker
export PATH="$PWD/bin:$PATH"
if ! make target/docker-image.txt; then
    if [ -f target/docker-image.txt ] && [ ! -s target/docker-image.txt ]; then
        make target/docker-image.txt
        die 'Make accepted an empty target after a failed build'
    fi
    die 'Make failed to build the image'
fi
test "$(cat target/docker-image.txt)" = 'sha256:1234' || die 'Make did not record the built image'
test "$(wc -l < calls.txt)" -eq 1 || die 'Make built the same image more than once'
