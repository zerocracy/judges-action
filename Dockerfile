# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:4.0@sha256:f225e75f1cbf9c287cefffa1498452dab5cfe9162412a0d25c7d29f2664617a5

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
