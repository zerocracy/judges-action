# GitHub Actions: Dynamic `run-name` After Workflow Start

## Problem

GitHub Actions workflow runs all share the same title in the Actions list.
It's impossible to set `run-name` to a value that depends on job results, because
`run-name` is evaluated at trigger time and only has access to `github`,
`inputs`, and `vars` contexts.

**Example desired output:**

```text
judges-action 0.17.17 did 8i/18d/42a to 3839 facts
```

where `8i/18d/42a to 3839 facts` is computed during the run.

## Current Workaround (insufficient)

```yaml
run-name: judges-action ${{ github.ref_name }}
```

This only shows static data available before the run starts.

## What We Need from GitHub

A mechanism to dynamically update the workflow run title during execution.
Three possible approaches, any one would solve the problem:

### 1. `{{ job }}` context in `run-name`

Allow `run-name` to reference `job.outputs` or `steps.*.outputs`.
The title would update as jobs complete.

```yaml
run-name: judges-action ${{ jobs.main.outputs.summary }}
```

### 2. PUT/PATCH API endpoint for `display_title`

```http
PATCH /repos/{owner}/{repo}/actions/runs/{run_id}
Content-Type: application/json

{
  "display_title": "judges-action 0.17.17 did 8i/18d/42a to 3839 facts"
}
```

This would allow any step to rename its own run before finishing.

### 3. Repository variable based update

Allow `vars` context to be set during a run, so the current run could
update the variable and immediately reflect the change in `run-name`.

---

## Related

- GitHub Community Discussion: <https://github.com/orgs/community/discussions/11396>
- Feature request: <https://github.com/actions/starter-workflows/issues/2289>
