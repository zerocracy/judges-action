# Judges Zerocracy Action

[![DevOps By Rultor.com](http://www.rultor.com/b/zerocracy/judges-action)](http://www.rultor.com/p/zerocracy/judges-action)

[![make](https://github.com/zerocracy/judges-action/actions/workflows/make.yml/badge.svg)](https://github.com/zerocracy/judges-action/actions/workflows/make.yml)
[![Hits-of-Code](https://hitsofcode.com/github/zerocracy/judges-action)](https://hitsofcode.com/view/github/zerocracy/judges-action)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/zerocracy/judges-action/blob/master/LICENSE.txt)

**ATTENTION**: The repository is in active development right now. It is
"work in progress" — most likely it won't work correctly if you use it "as is."
If you are interested in this plugin, better wait for a few weeks until it's
stable version 0.1.0 is released.

First, get a free authentication token from
[Zerocracy.com](https://www.zerocracy.com) and add it as
`ZEROCRACY_TOKEN` [secret][secrets] to your repository.
Then, add this `zerocracy.yml` file to your GitHub repository
at the `.github/workflows/` directory
(replace `foo` with the name of your team):

```yaml
name: zerocracy
'on':
  schedule:
    - cron: '0 * * * *'
concurrency:
  group: zerocracy
  cancel-in-progress: false
jobs:
  zerocracy:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: zerocracy/judges-action@0.0.59
        with:
          token: ${{ secrets.ZEROCRACY_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          repositories: yegor256/judges,yegor256/factbase,zerocracy/*
          factbase: foo.fb
      - uses: zerocracy/pages-action@0.0.40
        with:
          factbase: foo.fb
          options: |
            github_token=${{ secrets.GITHUB_TOKEN }}
      - uses: JamesIves/github-pages-deploy-action@v4.6.0
        with:
          folder: pages
          clean: false
```

In the file, there is only one place that you should configure:
the `repositories=...` should have a comma-separated list
of repositories where your team works (instead of `...`).

Once the file is added, GitHub will start running this job every ten
minutes, collecting information about most important activities of
your programmers. The plugin will give them awards for good things
they do (like fixing bugs) and will also punish them (by deducting points)
for bad things (like stale pull requests).

The plugin will also generate a summary `foo.html` file, which will
be automatically deployed to the `gh-pages` branch. You can configure
your GitHub repository to render the branch as a static website via
[GitHub Pages](https://pages.github.com/). Thus,
the summary page will be updated every ten minutes and you will see
who is the best performer in your team, similar to
[what we see](https://zerocracy.github.io/judges-action/zerocracy-vitals.html)
in our team.

## Configuration

The following options are expected by the plugin
(see how we [configure][ours] it):

* `token` (mandatory) is an authentication token from
  [Zerocracy.com](https://www.zerocracy.com)
* `options` (mandatory) is a list of `k=v` pairs, which are explained below
* `factbase` (mandatory) is the path of the [Factbase][factbase] file
  (where everything is kept)
* `repositories` (optional) is a comma-separated list of masks that
  determine the repositories to manage, where
  `yegor256/*` means all repos of the user,
  `yegor256/judges` means a specific repo,
  and
  `-yegor256/judges` means an exclusion of the repo from the list.
* `github_token` (optional) is an authentication GitHub access token
* `verbose` (optional) makes it print debugging info if set to `true`
* `cycles` (optional) is a number of update cycles to run

The following `k=v` pairs inside the `options` may be important:

* `github_token=...` is a default GitHub token, usually to be set to
`${{ secrets.GITHUB_TOKEN }}`
* `repositories=..` is a comma-separated list of masks that
determine the repositories to manage, where
`yegor256/*` means all repos of the user,
`yegor256/judges` means a specific repo,
and
`-yegor256/judges` means an exclusion of the repo from the list.

The `zerocracy/pages-action` plugin is responsible for rendering
the summary HTML page: its configuration is not explained here,
check its [own repository](https://github.com/zerocracy/pages-action).

## How to Contribute

In order to test this action, just run (provided, you have
[Ruby](https://www.ruby-lang.org/en/) 3+, [Bundler](https://bundler.io/),
and [GNU make](https://www.gnu.org/software/make/) installed):

```bash
bundle update
bundle exec rake
make
```

This should build a new Docker image named `judges-action`
and then run the entire cycle
inside a new Docker container. Obviously, you need to have
[Docker](https://docs.docker.com/get-docker/) installed. The Docker image
will be deleted by the end of the build (either success or failure).

In order to run "live" tests of some judges, do this:

```bash
bundle exec rake -- --live
```

In order to run a single test, try this:

```bash
bundle exec ruby test/judges/test-dimensions-of-terrain.rb -n test_total_repositories
```

[factbase]: https://github.com/yegor256/factbase
[secrets]: https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions
[ours]: https://github.com/zerocracy/judges-action/blob/master/.github/workflows/zerocracy.yml
