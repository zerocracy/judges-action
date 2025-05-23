# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

.ONESHELL:
.PHONY: clean test all entry rmi verify entries rubocop
.SHELLFLAGS := -e -o pipefail -c
SHELL := /bin/bash

export

all: rubocop test entry rmi verify entries

test: target/docker-image.txt
	img=$$(cat target/docker-image.txt)
	docker run --rm --entrypoint '/bin/bash' "$${img}" -c 'judges test --disable live --lib /action/lib /action/judges'
	echo "$$?" > target/test.exit

entry: target/docker-image.txt
	./test-action.sh "$$(cat $<)"
	echo "$$?" > target/entry.exit

rmi: target/docker-image.txt
	img=$$(cat $<)
	docker rmi "$${img}"
	rm "$<"

.SILENT:
entries:
	mkdir -p target/entries-logs
	for sh in $$(find entries -name '*.sh' -exec basename {} \;); do
		mkdir -p "target/$${sh}"
		if /bin/bash -c "cd \"target/$${sh}\" && exec \"$$(pwd)/entries/$${sh}\" \"$$(pwd)\" > \"$$(pwd)/target/entries-logs/$${sh}.txt\" 2>&1"; then
			echo "👍🏻 $${sh} passed"
		else
			cat "target/entries-logs/$${sh}.txt"
			echo "❌ $${sh} failed"
			exit 1
		fi
	done

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
