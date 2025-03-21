# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

.ONESHELL:
.PHONY: clean test all entry rmi verify rubocop
.SHELLFLAGS := -e -o pipefail -c
SHELL := /bin/bash

JUDGES = judges

export

all: rubocop test entry rmi verify

test: target/docker-image.txt
	img=$$(cat target/docker-image.txt)
	docker run --rm --entrypoint '/bin/bash' "$${img}" -c 'judges test --disable live --lib /action/lib /action/judges'
	echo "$$?" > target/test.exit

entry: target/docker-image.txt
	img=$$(cat $<)
	(
		echo 'testing=yes'
		echo 'repositories=yegor256/judges'
		echo 'max_events=3'
	) > target/opts.txt
	docker run --rm \
		-e "GITHUB_WORKSPACE=/tmp" \
		-e "GITHUB_REPOSITORY=zerocracy/judges-action" \
		-e "GITHUB_REPOSITORY_OWNER=zerocracy" \
		-e "GITHUB_SERVER_URL=https://github.com" \
		-e "GITHUB_RUN_ID=0000" \
		-e "INPUT_FACTBASE=/tmp/fake$$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 16).fb" \
		-e "INPUT_CYCLES=2" \
		-e "INPUT_VERBOSE=true" \
		-e "INPUT_PAGES=pages" \
		-e "INPUT_TOKEN=00000000-0000-0000-0000-000000000000" \
		-e "INPUT_GITHUB_TOKEN=00000000-0000-0000-0000-000000000000" \
		-e "INPUT_OPTIONS=$$(cat target/opts.txt)" \
		"$${img}"
	echo "$$?" > target/entry.exit

rmi: target/docker-image.txt
	img=$$(cat $<)
	docker rmi "$${img}"
	rm "$<"

verify:
	e1=$$(cat target/test.exit)
	test "$${e1}" = "0"
	e2=$$(cat target/entry.exit)
	test "$${e2}" = "0"

target/docker-image.txt: Makefile Dockerfile entry.sh Gemfile Gemfile.lock
	mkdir -p "$$(dirname $@)"
	docker build -t judges-action "$$(pwd)"
	docker build -t judges-action -q "$$(pwd)" > "$@"

clean:
	rm -f target
