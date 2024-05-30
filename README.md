# Judges Zerocracy Action

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
    - cron: '0,10,20,30,40,50 * * * *'
concurrency:
  group: zerocracy
  cancel-in-progress: false
jobs:
  zerocracy:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: zerocracy/judges-action@0.0.4
        with:
          token: ${{ secrets.ZEROCRACY_TOKEN }}
          options: |
            token=${{ secrets.GITHUB_TOKEN }}
            repositories=yegor256/judges,yegor256/*,-yegor256/test
          factbase: foo.fb
      - uses: zerocracy/pages-action@0.0.6
        with:
          factbase: foo.fb
      - uses: JamesIves/github-pages-deploy-action@v4.6.0
        with:
          branch: gh-pages
          folder: pages
          clean: false
```

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
who is the best performer in your team.

## Configuration

The following options are expected by the `zerocracy/judges-action` plugin:

* `token` is an authentication token from
  [Zerocracy.com](https://www.zerocracy.com)
* `options` is a list of `k=v` pairs, which are explained below.
* `factbase` is the path of the [Factbase][factbase] file
  (where everything is kept)
* `verbose` makes it print debugging info if set to `true`

The following `k=v` pairs inside the `options` may be important:

* `token=..` is a GitHub token (set it to `${{ secrets.GITHUB_TOKEN }}`
  or simply skip this option, the default will be used)
* `repositories=..` is a comma-separated list of masks that
  determine the repositories to manage, where
`yegor256/*` means all repos of the user,
`yegor256/judges` means a specific repo,
  and
  `-yegor256/judges` means an exclusion of the repo from the list.
* `max_events=..` is the maximum number of GitHub API events to scan
  at a time (better don't change it)

The `zerocracy/pages-action` plugin is responsible for rendering
the summary HTML page: its configuration is not explained here,
check its [own repository](https://github.com/zerocracy/pages-action).

## Awards & Punishments

In order to be _rewarded_, do the following:

* Create a new issue, which is labeled as `bug`, `enhancement`, or `question`
* Put one of those labels to an issue
* Merge a pull request
* Review a pull request
* Create a new release

In order to avoid _punishment_, do the following:

* Triage issues timely
* Review and merge/reject pull requests timely
* Release frequently
* Keep GitHub Action jobs green

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
will be deleted by the end of the build (either success or failure).

[factbase]: https://github.com/yegor256/factbase
[secrets]: https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions
