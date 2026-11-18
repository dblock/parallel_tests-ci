# Contributing

Read [Design](DESIGN.md), [Coding Guidance](AGENTS.md), and [Releasing](RELEASING.md). The repository currently validates a scaffold; consumer timing-history behavior is not implemented.

## Setup and Validation

Use Ruby 3.3 or newer; `.ruby-version` selects Ruby 4.0.9 for development. Install Bundler and run:

```sh
bundle install
bundle exec rake spec
bundle exec rake lint
bundle exec rake package
```

`bundle exec rake` runs tests and lint. `bundle exec rake build` only builds the gem; `bundle exec rake package` additionally inspects its file list, installs that exact archive into an owned temporary consumer, and loads the installed public entry point and upstream dependency. The temporary consumer is removed automatically; built gems remain under ignored `pkg/`.

Run final affected tests and lint before every commit/push, and package validation when public entry points, dependencies, or packaging change. Reuse passing results while the tested content and configuration are unchanged. Documentation-only changes need lint, not unrelated test or package reruns. Check available CI results without waiting after successful local checks.

`bundle exec rake lint` runs RuboCop with RSpec/Rake, Markdown prose, embedded Ruby, and spelling plugins. Use Title Case for Markdown headings and YAML workflow, job, and step display names; YAML capitalization is a documented convention, not a lint rule. Keep Markdown paragraphs on one source line. Fix typos and review `.spellcheck.txt` additions rather than disabling checks broadly. For formatting, use `bundle exec rubocop -a` and inspect the resulting diff.

CI keeps Test, Lint, and Package separate, uses explicit inline `matrix.entry` combinations, and tests the Ruby floor and current release. Coveralls consumes LCOV output. Danger runs in PR CI and exports a report for the trusted comment workflow; it is not a routine standalone local check. The changelog plugin supplies an update reminder only, because its default format parser does not match this repository's dash-style placeholder. The comment workflow becomes available after it exists on the default branch.

## Tests

Specs belong in `spec/`. The scaffold has no behavioral specs yet because the public entry point only loads the version; do not add trivial constant tests to populate the suite. Installed-gem validation uses `spec/fixtures/consumer/verify.rb` through the package task.

`bundle exec rake spec` writes HTML line/branch coverage to `coverage/index.html`, raw coverage to `coverage/.resultset.json`, and LCOV to `coverage/lcov.info`. Inspect line and branch gaps and aim close to complete coverage of project-owned runtime code as functionality is added. Test meaningful errors and edge cases, actual `parallel_rspec` subprocesses, and real installed consumers; do not inflate coverage with trivial constant/accessor checks or exclude runtime code.

Keep fixtures synthetic and offline at provider boundaries. Never publish gems, create real release tags, change credentials, or write to live GitHub/RubyGems services from tests. Use owned temporary directories and isolated Git remotes for release-tool validation.

## Pull Requests

The main checkout is `~/source/parallel_tests-ci/master`; its parent is a container, not a checkout. Work on `<username>/<topic>` branches in the existing checkout. Inspect status, branches, and worktrees before switching. Create sibling worktrees only for parallel tasks, never nested checkouts, and preserve unrelated changes and another task's branches.

Keep one coherent commit per PR and use rebase merges only, never squash merges or merge commits. Split dependent changes into focused PRs targeting the immediately preceding branch and register the complete native GitHub stack. Do not merge without explicit authorization. Development changes go through PRs; no ongoing direct-push exception is authorized.

Include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` in AI-assisted commits and disclose that an AI is acting on behalf of @dblock in AI-authored PRs/comments. Before rewriting a task-owned branch, fetch and record its remote tip, reconcile remote changes, validate, and push with `--force-with-lease=refs/heads/BRANCH:RECORDED_SHA`. Never force-push the default branch or rewrite another contributor's work.

After an authorized merge, fetch/prune and verify merged state through GitHub. Inspect dirty worktrees and dependent PRs before switching, removing only clean, unnecessary task-owned worktrees, and deleting branches with no retained work or dependencies. Never discard work as cleanup.

Update the applicable README, DESIGN, contributor guides, and changelog for meaningful changes. Use `- [#123](https://github.com/dblock/parallel_tests-ci/pull/123): Description - [@author](https://github.com/author).` above the final placeholder, with actual attribution. Predict the next PR number, verify it after creation, and correct both link and label when needed. The initial scaffold has no changelog entry. Leave implementation issues open for their PR's closing reference.

Check publication before bumping versions, keep an unreleased version unchanged, and synchronize the version constant and Next heading. Verify current stable dependency/tool releases and their compatibility rather than copying old examples. See [Releasing](RELEASING.md) for the separate authorization needed for releases. Preserve editable artwork and provenance; artwork requires its own approved concept and focused PR.
