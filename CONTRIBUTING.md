# Contributing

See [Design](DESIGN.md) for behavior, [Coding Guidance](AGENTS.md) for invariants, and [Releasing](RELEASING.md) for publication.

## Setup and Validation

Use `.ruby-version` for development; Ruby 3.3 is the supported minimum.

```sh
bundle install
```

| Command                              | Checks                                                                                |
| ---                                  | ---                                                                                   |
| `bundle exec rake`                   | Specs and lint.                                                                       |
| `bundle exec rake spec`              | Unit/integration specs and line/branch coverage.                                      |
| `bundle exec rake lint`              | Ruby, Markdown, embedded Ruby, and spelling.                                          |
| `bundle exec rake package`           | Build and inspect the gem; install that exact archive and execute/collect two shards. |
| `actionlint .github/workflows/*.yml` | GitHub Actions syntax and expressions.                                                |

Before committing or pushing, run affected specs and lint, plus package validation for public-entry, dependency, execution, or packaging changes. For docs-only changes, run lint. Reuse passing results for unchanged content; check CI later.

Use single-line Markdown paragraphs and Title Case for headings and workflow, job, and step names. Review `bundle exec rubocop -a` corrections and `.spellcheck.txt` additions; keep lint exceptions narrow.

## Tests

Framework-neutral specs live in `spec/parallel_tests/ci/`, with shared examples in `shared/` and framework-specific specs, suites, and consumer checks in their respective framework directories. Synthetic RSpec suite files omit `_spec.rb` so they run only in subprocesses; `consumer/verify_frameworks.rb` checks cross-framework detection against the installed archive. Use real subprocesses for execution and stub GitHub CLI responses at API boundaries. Keep tests offline, with owned temporary directories and isolated release remotes.

Inspect `coverage/index.html` for line/branch gaps; raw data is in `coverage/.resultset.json` and LCOV in `coverage/lcov.info`. Cover errors and edge cases, not trivial assertions; do not exclude runtime code. Package validation removes its temporary consumer; archives remain in ignored `pkg/`.

CI tests the Ruby minimum/current release on Linux and the current release on macOS and Windows, the standalone action with RSpec and Minitest on Linux and Windows, and the shared workflow for default names, templates, Linux/macOS/Windows runners with RSpec and Minitest, runner labels, label arrays, and group objects, cached/uncached gems, full checkout, and execution/retention controls. Keep explicit inline `matrix.entry` combinations and separate Test, Lint, and Package workflows. Coveralls receives LCOV; Danger runs only in PR CI and exports its report for the trusted comment workflow. Empty reports create no new comments; existing reports are still updated. Comment workflow changes take effect after merge.

## Pull Requests

Use `<username>/<topic>` branches in `~/source/parallel_tests-ci/master`; sibling worktrees are for parallel tasks only. Inspect status and worktree ownership before switching; preserve unrelated changes.

Development requires PRs; see [Releasing](RELEASING.md#prerequisites) for the authorized release automation exception and branch rules.

Keep one coherent commit per PR. Stack dependent PRs against their immediate predecessor and preserve native stack membership. Use rebase merges only, with explicit merge authorization. Include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` in AI-assisted commits and disclose AI authorship on behalf of @dblock in PRs/comments.

Before rewriting a task-owned branch, fetch/record its remote tip, reconcile changes, and validate. Push with `--force-with-lease=refs/heads/BRANCH:RECORDED_SHA`; never force-push the default branch. After merging, verify GitHub's merged state and dependencies before removing clean task-owned branches/worktrees.

Add attributed, linked PR entries above the Next changelog placeholder. Predict the number, then verify/correct it after opening the PR. Use closing references for implementation issues; do not close them manually. Verify current stable dependency/tool versions before selecting them. Check publication before version bumps; keep unpublished versions unchanged and synchronize the version constant and Next heading.
