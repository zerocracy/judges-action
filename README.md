# Judges Zerocracy Action

[![make](https://github.com/zerocracy/judges-action/actions/workflows/make.yaml/badge.svg)](https://github.com/zerocracy/judges-action/actions/workflows/make.yaml)
[![Hits-of-Code](https://hitsofcode.com/github/zerocracy/judges-action)](https://hitsofcode.com/view/github/zerocracy/judges-action)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/zerocracy/judges-action/blob/master/LICENSE.txt)

Add this `zerocracy.yml` file to your GitHub repository
at the `.github/workflows/` directory
(replace `foo` with the name of your team):

```yaml
name: zerocracy
'on':
  schedule:
    - cron: '0,10,20,30,50,50 * * * *'
jobs:
  zerocracy:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: foo.fb
          key: zerocracy
      - uses: zerocracy/judges-action@master
        with:
          options: |
            token=${{ secrets.GITHUB_TOKEN }}
            repositories=yegor256/judges,yegor256/*,-yegor256/test
          factbase: foo.fb
      - uses: zerocracy/pages-action@master
        with:
          factbase: recent.fb
      - uses: JamesIves/github-pages-deploy-action@v4.6.0
        with:
          branch: gh-pages
          folder: pages
          clean: false
```

Once the file is added, GitHub will start running this job every ten
minutes, collecting information about most important activities of
your programmers. The plugin will give them awards for good things
they do (like fixing bugs) and will punish them by deducting points
for bad things (like delays in reviewing pull requests).

The plugin will also generate a summary `foo.html` file, which will
be automatically deployed to the `gh-pages` branch.

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
