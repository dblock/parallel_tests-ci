# Working on Parallel Tests CI

Read [Contributing](CONTRIBUTING.md) for validation, CI, and PR rules, [Design](DESIGN.md) for behavior, and [Releasing](RELEASING.md) before release work.

## Scope and Layout

Runtime: `lib/parallel_tests/ci/`. Specs, synthetic suites, and installed-consumer checks: `spec/parallel_tests/ci/`. Workflows: `.github/workflows/`. Support Ruby 3.3+; use `.ruby-version` for development. `shards.yml` defines each setup step shared by its jobs once, as a YAML anchor (`&checkout`, `&setup-ruby`, and so on), and reuses it with aliases; edit the anchored definition, and keep `YAML.safe_load` callers passing `aliases: true`.

Use the documented `parallel_tests` API for partitioning, timing, and unknown-runtime estimation for RSpec and Minitest. Do not add a scheduler, patch dependencies, parse console output as an API, or introduce other providers or a public CLI.

## Runtime Invariants

- Share one immutable plan/history snapshot; reject changed spec paths or sizes.
- Emit explicit `matrix.entry` objects, never matrix include/exclude or Cartesian axes.
- Fall back centrally when history is unusable; never skip tests or fabricate durations.
- Write success markers only after passing tests. Collect every shard's newest successful attempt for the same fingerprint; reject duplicate latest reports.
- Trust baselines only from successful default-branch push workflows. Fork PRs remain read-only; never execute artifacts, use `pull_request_target`, or request extra tokens.

## Maintenance

Preserve artwork sources, provenance, and rendering instructions. Do not merge, publish, tag, or change authentication without explicit authorization.
