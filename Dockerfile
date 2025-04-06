# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:3.4

LABEL "repository"="https://github.com/zerocracy/judges-action"
LABEL "maintainer"="Yegor Bugayenko"
LABEL "version"="0.3.0"

RUN apt-get update \
    && apt-get install --no-install-recommends -y curl=7.88.* jq=1.6* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /action
COPY entry.sh /action
COPY judges /action/judges
COPY lib /action/lib
COPY Gemfile /action
COPY Gemfile.lock /action

RUN bundle update --gemfile=/action/Gemfile

ENTRYPOINT ["/action/entry.sh", "/action"]
