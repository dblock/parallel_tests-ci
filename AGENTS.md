# Working on Parallel Tests CI

Read [Contributing](CONTRIBUTING.md) for commands and workflow and [Design](DESIGN.md) for the agreed integration boundaries and trust invariants.

## Scope and Layout

Runtime code belongs in `lib/parallel_tests/ci/`, unit/integration specs in `spec/parallel_tests/ci/`, synthetic suites and the installed consumer in `spec/fixtures/`, and CI workflows in `.github/workflows/`. Ruby 3.3 is the supported floor; `.ruby-version` selects current development Ruby. The gem and shared workflow must use compatible refs; 0.1.0 is unreleased.

Delegate partitioning, timing collection, and unknown-runtime estimation to the documented `parallel_tests` interfaces. Search for maintained libraries before implementing generic functionality. Do not patch dependencies, add a scheduler, parse console output as an API, create a public CLI, or build a provider framework. GitLab work is not in scope.

## Runtime Invariants

One immutable historical snapshot, grouping mode, and shard count govern every worker. Generate explicit JSON entries for `matrix.entry`; never use matrix include/exclude or unrelated Cartesian axes. Missing or unusable history falls back centrally. First-run measurement is automatic, historical input stays separate from output, and incomplete or duplicate reports cannot replace a complete baseline.

Keep the selected file set/sizes stable after preparation. Measurement markers require successful execution and identify both the exact plan/history fingerprint and retry attempt. Retries select the newest successful report per shard for that plan, never fill gaps from another plan, and never fabricate durations for files without timed example groups.

Only successful trusted default-branch push runs provide authoritative timings. Fork PRs use read-only access and cannot publish baselines. Never execute artifacts, request a PAT, use `pull_request_target`, hide test failures, or skip tests because history is unavailable. Keep report handling separate from GitHub transport without speculative adapters.

## Validation and Maintenance

Run `bundle exec rake spec`, `bundle exec rake lint`, and, for package/public-entry changes, `bundle exec rake package` before committing or pushing. `bundle exec rake` runs tests and lint together. See Contributing for installed-consumer validation and line/branch coverage. Aim close to complete coverage of project-owned runtime behavior, including errors and real subprocesses, without trivial assertions or coverage exclusions. Danger runs only in PR CI.

Keep Test, Lint, and Package workflows separate, use explicit inline `matrix.entry` combinations, and retain Coveralls and PR-only Danger reporting. Local lint includes Ruby, Markdown prose, embedded Ruby, and spelling. Use Title Case for Markdown headings and YAML workflow, job, and step display names; YAML capitalization is a documented convention, not a lint rule. Keep Markdown paragraphs on one source line, review `.spellcheck.txt`, and use only narrow lint exceptions with concrete reasons.

Use the branch, stack, coherent-commit, rebase-only merge, guarded update, and cleanup rules in Contributing. Preserve unrelated work and active branches. Include the Copilot co-author trailer and disclose AI authorship on behalf of @dblock in AI-authored PRs/comments.

Keep README focused, DESIGN about the current design, and commands/invariants in contributor guidance. Add meaningful changes to the current Next changelog section; keep unreleased versions unchanged. Maintain editable artwork, provenance, and rendering instructions when artwork is introduced.

Publication, tags/releases, authentication, trusted-publisher configuration, and release dispatch each require explicit authorization. Release tooling is provisional; current default-branch rules require PRs and deliberately block direct release-metadata pushes. See [Releasing](RELEASING.md). Do not merge or publish because checks passed.
