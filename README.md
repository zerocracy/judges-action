# Judges Zerocracy Action

[![DevOps By Rultor.com](https://www.rultor.com/b/zerocracy/judges-action)](https://www.rultor.com/p/zerocracy/judges-action)

[![make](https://github.com/zerocracy/judges-action/actions/workflows/make.yml/badge.svg)](https://github.com/zerocracy/judges-action/actions/workflows/make.yml)
[![discipline](https://zerocracy.github.io/judges-action/zerocracy-badge.svg)](https://zerocracy.github.io/judges-action/zerocracy-vitals.html)
[![Hits-of-Code](https://hitsofcode.com/github/zerocracy/judges-action)](https://hitsofcode.com/view/github/zerocracy/judges-action)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/zerocracy/judges-action/blob/master/LICENSE.txt)

First, get a free authentication token from [Zerocracy.com] and add it as
  `ZEROCRACY_TOKEN` [secret][secrets] to your repository.

Then, create a new [personal access token][PAT]
  and add it as a `ZEROCRACY_PAT` secret to your repository.
Don't forget to give it full "repository access".
You may ignore this, if all your repositories are public.

Then, add this `zerocracy.yml` file to your GitHub repository
  at the `.github/workflows/` directory
  (replace `foo` with the name of your team, `yegor256` with the name of the
  account owner, and `42` with anything between zero and `60`):

```yaml
name: zerocracy
'on':
  schedule:
    - cron: '42 * * * *'
concurrency:
  group: zerocracy
  cancel-in-progress: false
jobs:
  zerocracy:
    if: github.repository_owner == 'yegor256'
    runs-on: ubuntu-24.04
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4
      - uses: zerocracy/judges-action@0.17.8
        with:
          token: ${{ secrets.ZEROCRACY_TOKEN }}
          github-token: ${{ secrets.ZEROCRACY_PAT }}
          repositories: yegor256/foo
          factbase: foo.fb
      - uses: zerocracy/pages-action@0.6.3
        with:
          github-token: ${{ secrets.ZEROCRACY_PAT }}
          factbase: foo.fb
      - uses: JamesIves/github-pages-deploy-action@v4.6.0
        with:
          folder: pages
          clean: false
```

In the file, there is only one place that you should configure:
  the `repositories=...` should have a comma-separated list
  of repositories where your team works (instead of `...`).
If you have more than one repository in your product, list them here.
The CI job must only be added to one of them.

Once the file is added, GitHub starts running this job hourly,
  collecting information about most important activities of
  your programmers.
The plugin gives them awards for good things
  they do (like fixing bugs) and also punishes them (by deducting points)
  for bad things (like stale pull requests).

The plugin also generates a summary `foo.html` file, which
  is automatically deployed to the `gh-pages` branch.
You can configure your GitHub repository to render the branch
  as a static website via [GitHub Pages].
Thus, the summary page is updated hourly and you see
  who is _subjectively_ the best performer in your team, similar to
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
* `github-token` (optional) is an authentication GitHub access token
* `verbose` (optional) makes it print debugging info if set to `true`
* `timeout` (optional) is how many minutes each judge can spend
* `lifetime` (optional) is how many minutes the entire update can take
* `cycles` (optional) is a number of update cycles to run
* `sqlite-cache` (optional) is a path of SQLite database file with HTTP cache
* `bots` (optional) is a comma-separated list of GitHub user logins to mark as bots

The following `k=v` pairs inside the `options` may be important:

* `github_token=...` is a default GitHub token, usually to be set to
  `${{ secrets.GITHUB_TOKEN }}`
* `repositories=..` is a comma-separated list of masks that
  determine the repositories to manage, where
  `yegor256/*` means all repos of the user,
  `yegor256/judges` means a specific repo,
  and
  `-yegor256/judges` means an exclusion of the repo from the list.
* `sqlite_cache_maxsize=10M` is the maximum size of HTTP cache file
* `sqlite_cache_maxsize=10K` is the maximum size of a single HTTP entry to cache

The `zerocracy/pages-action` plugin is responsible for rendering
  the summary HTML page: its configuration is not explained here,
  check its [own repository](https://github.com/zerocracy/pages-action).

## How to Contribute

You need to have
  [GNU Bash] 5+,
  [GNU Make] 4+,
  [Ruby] 3+,
  [Bundler],
  and
  [GNU parallel] installed.

Then, just run:

```bash
bundle update
make
```

This should build a new Docker image named `judges-action`
  and then run the entire cycle
  inside a new Docker container.
Obviously, you need to have [Docker] installed.
The Docker image is deleted by the end of the build
  (either success or failure).

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
[PAT]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[Ruby]: https://www.ruby-lang.org/en/
[Bundler]: https://bundler.io/
[GNU Parallel]: https://www.gnu.org/software/parallel/
[GNU Make]: https://www.gnu.org/software/make/
[GNU Bash]: https://www.gnu.org/software/bash/
[Docker]: https://docs.docker.com/get-docker/
[GitHub Pages]: https://pages.github.com/
[Zerocracy.com]: https://www.zerocracy.com
