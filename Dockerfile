# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:4.0.10@sha256:84e854507d7f2ffc9061e32d47c16d7413bcb1fa55ec29c1927f9e4d62fa6cf3

LABEL "repository"="https://github.com/zerocracy/judges-action"
LABEL "maintainer"="Yegor Bugayenko"
LABEL "version"="0.0.0"

RUN apt-get update \
    && apt-get install --no-install-recommends -y curl=* jq=* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /action
COPY Gemfile /action
COPY Gemfile.lock /action
RUN bundle config set frozen true && bundle install --gemfile=/action/Gemfile

COPY judges /action/judges
COPY lib /action/lib
COPY entry.sh /action

ENTRYPOINT ["/action/entry.sh", "/action"]
