# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:4.0@sha256:f30806f0d42bd9fb2fc45a3f3fe11963bc863adbb12a96605030f8667404e7a7

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
RUN bundle config set deployment true \
    && bundle install

COPY judges /action/judges
COPY lib /action/lib
COPY entry.sh /action

ENTRYPOINT ["/action/entry.sh", "/action"]
