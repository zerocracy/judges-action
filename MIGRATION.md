# WebMock → VCR Migration

Date: 2025-05-31
Issue: [#760](https://github.com/zerocracy/judges-action/issues/760)

## What and Why

Replaced WebMock stubs with VCR cassettes in all tests.

**Before:** Each test had dozens of lines of manual HTTP stubbing:

```ruby
def test_finds_name
  WebMock.disable_net_connect!
  stub_request(:get, 'https://api.github.com/user/444', body: { login: 'lebowski' })
  fb = Factbase.new
  f = fb.insert; f.who = 444
  load_it('who-has-name', fb)
  assert_equal('lebowski', fb.query('(exists name)').each.first.name)
end
```

**After:** VCR replays recorded HTTP interactions from YAML files:

```ruby
def test_finds_name
  rate_limit_up
  fb = Factbase.new
  f = fb.insert; f.who = 444
  VCR.use_cassette('who-has-name/finds_name') { load_it('who-has-name', fb) }
  assert_equal('lebowski', fb.query('(exists name)').each.first.name)
end
```

## Why VCR instead of FakeHub

The issue suggested trying [FakeHub](https://github.com/h1alexbel/fakehub). After
evaluation, VCR was chosen because:

- **Simpler** — no server to run, no port conflicts, no setup in CI
- **Minimal changes** — plugs into existing HTTP stack via WebMock hook
- **Realistic** — responses are exact copies of what GitHub returns
- **Deterministic** — cassettes are committed to repo, same data every run

The decision follows our [testing strategy playbook](.opencode/PLAYBOOK.md):
*VCR by default, alternatives only if VCR is insufficient.*

## Results

| Metric | Value |
|---|---|
| Test files migrated | 28/28 (100%) |
| Tests on VCR | ~200 |
| Tests remaining on WebMock | 0 |
| VCR cassettes | 172 |
| Lines of WebMock stubs removed | -3910 |
| Lines of VCR wrappers added | +474 |

## VCR Configuration

```ruby
WebMock.disable_net_connect!

VCR.configure do |config|
  config.cassette_library_dir = 'test/vcr_cassettes'
  config.hook_into(:webmock)
  config.ignore_request { |r| r.uri.include?('/rate_limit') }
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: :none,
    match_requests_on: %i[method uri],
    allow_playback_repeats: true
  }
end
```

Key settings:

- `record: :none` — never record, only replay
- `ignore_request` for `/rate_limit` — rate limit checks go through WebMock stubs (`rate_limit_up`)
- `allow_playback_repeats: true` — same URL may be called multiple times (e.g., `/repos/foo/foo` during `unmask_repos`)
- `match_requests_on: [:method, :uri]` — exact URI match; date-parameterized URLs need care

## Hard Problems and Solutions

Four tests could not be handled by the automated cassette generator and required
manual intervention.

### 1. Sequential Responses (same URL, two different replies)

**File:** `test-github-events.rb` → `test_rescues_forbidden_on_closed_pull_request_reviews_lookup`

The judge called `Fbe.octo.pull_request_reviews()` twice: first directly (line 179)
to set `fact.review`, then inside `Jp.count_suggestions` (line 192). The test
expected a 403 on the first call and 200 on the second. VCR with
`allow_playback_repeats: true` always returns the first match.

**Solution:** Refactored the judge (`judges/github-events/github-events.rb`) to
call `pull_request_reviews` once and pass the result to `count_suggestions`:

```ruby
# Before:
review = Fbe.octo.pull_request_reviews(rname, fact.issue).first
fact.review = review[:submitted_at] if review
fact.suggestions = Jp.count_suggestions(rname, fact.issue, author) if author

# After:
reviews = Fbe.octo.pull_request_reviews(rname, fact.issue)
fact.review = reviews.first[:submitted_at] if reviews.any?
fact.suggestions = Jp.count_suggestions(rname, fact.issue, author, reviews) if author
```

On 403/NotFound, the rescue block returns `[]`: `fact.review` is not set,
`count_suggestions(..., [])` returns 0 without additional API calls.

### 2. Dynamic SHA in URL

**File:** `test-github-events.rb` → `test_release_event_contributors`

The release event handler calls `/commits?per_page=100&sha=<computed_sha>`,
where the SHA is determined at runtime from a previous API response. The cassette
generator cannot know the SHA in advance.

**Solution:** Manually created a cassette. The SHA is deterministic: the
`earliest()` helper calls `/commits?per_page=100`, takes the last commit's SHA
(`69a28ba...`), then calls `/commits?per_page=100&sha=69a28ba...`. Since the
first response is frozen in the cassette, the computed SHA is always the same.

### 3. Dynamic URLs in Loops

**Files:** `test-dimensions-of-terrain.rb` → two tests

```ruby
%w[bad good].each do |name|
  stub_github("https://api.github.com/repos/foo/#{name}", body: { ... })
end
```

The cassette generator does not evaluate Ruby string interpolation at runtime.

**Solution:** Manually created cassettes with explicit URLs (`repos/foo/bad`,
`repos/foo/good`).

## How to Add a New Cassette

For simple cases (static URLs, single responses):

```bash
# 1. Write test with WebMock stubs (as before)
# 2. Generate cassette:
ruby _gen_all.rb
# 3. Rewrite test:
ruby _rewrite.rb test/judges/test-xxx.rb
# 4. Verify:
bundle exec ruby -Itest test/judges/test-xxx.rb
```

For complex cases (helpers, regex URLs, sequential responses, Ruby expressions
in body): create the cassette manually by copying an existing one and adjusting
the URL, status, and response body.

## Running Tests

```bash
# Single file (coverage requires single-file run)
bundle exec ruby -Itest test/judges/test-who-has-name.rb

# Single test
bundle exec ruby -Itest test/judges/test-who-has-name.rb -n test_finds_name

# All tests
bundle exec rake test
```

## Migration Tools

- `_gen_all.rb` — parses test files, extracts `stub_github`/`stub_request` calls,
  generates VCR cassettes
- `_rewrite.rb` — removes WebMock stubs from tests, wraps `load_it` in
  `VCR.use_cassette`
