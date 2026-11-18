# Working on Parallel Tests CI

Read [Contributing](CONTRIBUTING.md) for commands and workflow and [Design](DESIGN.md) for the agreed integration boundaries and trust invariants.

## Scope and Layout

The current tree is a scaffold, not a working consumer integration. Runtime code belongs in `lib/parallel_tests/ci/`, tests in `spec/`, and CI workflows in `.github/workflows/`. Ruby 3.3 is the supported floor; `.ruby-version` selects current development Ruby.

Delegate partitioning, timing collection, and unknown-runtime estimation to the documented `parallel_tests` interfaces. Search for maintained libraries before implementing generic functionality. Do not patch dependencies, add a scheduler, parse console output as an API, create a public CLI, or build a provider framework. GitLab work is not in scope.

## Runtime Invariants

One immutable historical snapshot, grouping mode, and shard count govern every worker. Generate explicit JSON entries for `matrix.entry`; never use matrix include/exclude or unrelated Cartesian axes. Missing or unusable history falls back centrally. First-run measurement is automatic, historical input stays separate from output, and incomplete or duplicate reports cannot replace a complete baseline.

Only successful trusted default-branch push runs provide authoritative timings. Fork PRs use read-only access and cannot publish baselines. Never execute artifacts, request a PAT, use `pull_request_target`, hide test failures, or skip tests because history is unavailable. Keep report handling separate from GitHub transport without speculative adapters.

## Validation and Maintenance

Run `bundle exec rake spec`, `bundle exec rake lint`, and, for package/public-entry changes, `bundle exec rake package` before committing or pushing. `bundle exec rake` runs tests and lint together. See Contributing for installed-consumer validation and line/branch coverage. Aim close to complete coverage of project-owned runtime behavior, including errors and real subprocesses, without trivial assertions or coverage exclusions. Danger runs only in PR CI.

Keep Test, Lint, and Package workflows separate, use explicit inline `matrix.entry` combinations, and retain Coveralls and PR-only Danger reporting. Local lint includes Ruby, Markdown prose, embedded Ruby, and spelling. Use Title Case for Markdown headings and YAML workflow, job, and step display names; YAML capitalization is a documented convention, not a lint rule. Keep Markdown paragraphs on one source line, review `.spellcheck.txt`, and use only narrow lint exceptions with concrete reasons.

Use the branch, stack, coherent-commit, rebase-only merge, guarded update, and cleanup rules in Contributing. Preserve unrelated work and active branches. Include the Copilot co-author trailer and disclose AI authorship on behalf of @dblock in AI-authored PRs/comments.

Keep README focused, DESIGN about the current design, and commands/invariants in contributor guidance. Add meaningful changes to the current Next changelog section; keep unreleased versions unchanged. Maintain editable artwork, provenance, and rendering instructions when artwork is introduced.

Publication, tags/releases, authentication, trusted-publisher configuration, and release dispatch each require explicit authorization. Release tooling is provisional; current default-branch rules require PRs and deliberately block direct release-metadata pushes. See [Releasing](RELEASING.md). Do not merge or publish because checks passed.
