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

Run affected tests and lint before committing/pushing; add package validation for public-entry, dependency, execution, or packaging changes. Documentation-only changes need lint. Reuse passing results for unchanged content; inspect CI without waiting after local checks pass.

Keep prose concise and paragraphs on one source line. Use Title Case headings and workflow/job/step display names. Format with `bundle exec rubocop -a`, inspect corrections, and review `.spellcheck.txt` additions instead of suppressing typos.

## Tests

Specs live in `spec/parallel_tests/ci/`; synthetic suites in `spec/fixtures/suite/` omit `_spec.rb` so they run only in subprocesses. `spec/fixtures/consumer/verify.rb` exercises the installed archive. Use real subprocesses for execution and stub GitHub CLI responses at API boundaries. Keep tests offline, with owned temporary directories and isolated release remotes.

Inspect `coverage/index.html` for line/branch gaps; raw data is in `coverage/.resultset.json` and LCOV in `coverage/lcov.info`. Cover errors and edge cases, not trivial assertions; do not exclude runtime code. Package validation removes its temporary consumer; archives remain in ignored `pkg/`.

CI tests the Ruby minimum/current release and calls the shared workflow for default names, templates, Linux/macOS runners, cached/uncached gems, full checkout, and execution/retention controls. Keep explicit inline `matrix.entry` combinations and separate Test, Lint, and Package workflows. Coveralls receives LCOV; Danger runs only in PR CI and exports its report for the trusted comment workflow. Empty reports create no new comments; existing reports are still updated. Comment workflow changes take effect after merge.

## Pull Requests

Use `<username>/<topic>` branches in `~/source/parallel_tests-ci/master`; sibling worktrees are for parallel tasks only. Inspect status and worktree ownership before switching; preserve unrelated changes.

Authorized manual release automation pushes release metadata and the next development version directly to `master`. Branch rules allow fast-forward pushes by all writers while blocking force pushes and deletion with no bypass actors; this does not change the ordinary development PR policy. The `release` environment requires @dblock approval and accepts only `master`.

Keep one coherent commit per PR. Stack dependent PRs against their immediate predecessor and preserve native stack membership. Use rebase merges only, with explicit merge authorization. Include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` in AI-assisted commits and disclose AI authorship on behalf of @dblock in PRs/comments.

Before rewriting a task-owned branch, fetch/record its remote tip, reconcile changes, and validate. Push with `--force-with-lease=refs/heads/BRANCH:RECORDED_SHA`; never force-push the default branch. After merging, verify GitHub's merged state and dependencies before removing clean task-owned branches/worktrees.

Add attributed, linked PR entries above the Next changelog placeholder. Predict the number, then verify/correct it after opening the PR. Use closing references for implementation issues; do not close them manually. Verify current stable dependency/tool versions before selecting them. Check publication before version bumps; keep unpublished versions unchanged and synchronize the version constant and Next heading.
