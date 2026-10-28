# Reusable Workflows

This directory contains GitHub Actions workflows for `zerocracy/judges-action`. Several of these workflows are designed to be **reusable** across other Zerocracy repositories via [`workflow_call`](https://docs.github.com/en/actions/sharing-automations/reusing-workflows).

## Source of Truth

`zerocracy/judges-action` is the **source of truth** for shared CI/CD workflows in the Zerocracy ecosystem. The following workflows are marked as reusable:

| Workflow | Reusable |
|----------|----------|
| `actionlint.yml` | ✅ `workflow_call` |
| `copyrights.yml` | ✅ `workflow_call` |
| `markdown-lint.yml` | ✅ `workflow_call` |
| `pdd.yml` | ✅ `workflow_call` |
| `reuse.yml` | ✅ `workflow_call` |
| `typos.yml` | ✅ `workflow_call` |
| `xcop.yml` | ✅ `workflow_call` |
| `yamllint.yml` | ✅ `workflow_call` |

## How to Use in Another Repository

Replace the local workflow file with a thin wrapper that delegates to judges-action. Example for `copyrights.yml`:

```yaml
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT
---
name: copyrights
'on':
  push:
    branches:
      - master
  pull_request:
    branches:
      - master
jobs:
  copyrights:
    uses: zerocracy/judges-action/.github/workflows/copyrights.yml@master
```

> **Important:** Pin to a specific commit SHA instead of `@master` for production stability:
> ```yaml
> uses: zerocracy/judges-action/.github/workflows/copyrights.yml@<sha>
> ```

## Repo-Specific Workflows (NOT reusable)

These workflows are specific to `zerocracy/judges-action` and should NOT be referenced from other repos:

- `zerocracy.yml` — the main action runner
- `up.yml` — version update PR
- `titles.yml` — AI issue title generation
- `rake.yml` — Ruby tests
- `make.yml` — Docker build
- `bashate.yml`, `checkmake.yml`, `hadolint.yml`, `shellcheck.yml` — infra-specific

## Notes for Migration

### SHA Pinning

`zerocracy/judges-action` pins all third-party actions to exact commit SHAs (e.g., `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6`). FBE already pins its external actions to commit SHAs, while Pages Action uses version tags (e.g., `@v7`). Reusable workflows give callers the shared SHA-pinned action versions; for FBE, pinning is an existing property, rather than a new migration benefit.

### Known Differences Between Repos

FBE and Pages Action baselines checked on 2026-10-28.

| Aspect | judges-action | fbe | pages-action | judges |
|--------|--------------|-----|--------------|--------|
| Action versions | SHA-pinned | SHA-pinned | Version tags | Semver tags |
| Branch filter | `branches: [master]` | `copyrights.yml`: master; `xcop.yml`: paths only | `copyrights.yml` and `xcop.yml`: master | `branches: [master]` |
| SPDX header | Zerocracy | Zerocracy | Zerocracy | Yegor Bugayenko |

### Breaking Changes to Watch For

1. **Branch filter narrowing** — If your repo relies on workflows running on all branches (e.g., `fbe/xcop.yml` filters paths without restricting branches), adopting the example wrapper's `branches: [master]` will narrow its triggers. FBE's `copyrights.yml` already restricts both `push` and `pull_request` to `master`
2. **Config file paths** — `typos.yml` in fbe uses `.github/.typos.toml` while judges-action uses `.github/typos.toml`. Standardize paths before migrating
3. **SPDX headers** — `yegor256/judges` has `Copyright (c) 2024-2026 Yegor Bugayenko`. This will change when referencing judges-action's workflows
