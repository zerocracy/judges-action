# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:4.0.6@sha256:8dc3950712ad2078bdd275b890419ba2fd3aab5a0653b291a7325f0d8a24ca05

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
