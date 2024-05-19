# Judges Zerocracy Action

[![test](https://github.com/zerocracy/judges-action/actions/workflows/test.yml/badge.svg)](https://github.com/zerocracy/judges-action/actions/workflows/test.yml)
[![Hits-of-Code](https://hitsofcode.com/github/zerocracy/judges-action)](https://hitsofcode.com/view/github/zerocracy/judges-action)
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
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: recent.fb
          key: zerocracy
          restore-keys: zerocracy
      - uses: zerocracy/judges-action@master
        with:
          options: |
            github_token=${{ secrets.GITHUB_TOKEN }}
            github_repositories=yegor256/judges
          factbase: recent.fb
      - uses: JamesIves/github-pages-deploy-action@v4.6.0
        with:
          branch: gh-pages
          folder: zerocracy-pages
          clean: false
```

## How to Contribute

In order to test this action, just run (provided, you have
[GNU make](https://www.gnu.org/software/make/) installed):

```bash
make
```

This should build a new Docker image named `judges-action`
and then run the entire cycle
inside a new Docker container. Obviously, you need to have
[Docker](https://docs.docker.com/get-docker/) installed. The Docker image
will be deleted by the end of Make build.
