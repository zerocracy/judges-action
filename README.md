# Judges Zerocracy Action

[![test](https://github.com/zerocracy/judges-action/actions/workflows/test.yml/badge.svg)](https://github.com/zerocracy/judges-action/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/zerocracy/judges-action/blob/master/LICENSE.txt)

Add it to your project:

```yaml
name: zerocracy
on:
  push:
jobs:
  zerocracy:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v2
      - uses: zerocracy/judges-action@0.0.1
```

## How to Contribute

In order to test this action, just run:

```bash
make test
```

This should build a new Docker image and then try to use it
in order to render a simple `test.tex` document. You need to have
[Docker](https://docs.docker.com/get-docker/) installed.
