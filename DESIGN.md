# Design

## Purpose and Status

`parallel_tests-ci` provides reusable RSpec/GitHub Actions integration around [parallel_tests](https://github.com/grosser/parallel_tests). The gem handles report validation and the shared run plan; `.github/workflows/rspec.yml` owns preparation, execution, artifact transport, and baseline publication. Version 0.1.0 is not yet published.

Users add the gem and one shared GitHub Actions workflow to their existing project. No manual command, initial measurement run, committed timing report, personal token, or extra service is required. RSpec and GitHub Actions are the only first-version integrations. There is no planned GitLab implementation, hosted service, public CLI, or generic provider framework.

## Reuse the Existing Scheduler

`parallel_tests` owns test execution, timing collection, unknown-runtime estimation, and runtime-based partitioning. Use its documented formatter and command-line options rather than a custom sharding algorithm, monkey patches, internal dependency mutation, or console-output parsing. The project owns only timing-report handling and CI orchestration.

The portable Ruby report layer is separate from GitHub artifact discovery and transport. This keeps the implementation understandable without adding abstractions for hypothetical integrations.

## Existing Integrations

[StrongMind's reusable RSpec workflow](https://github.com/StrongMind/public-reusable-workflows/blob/main/.github/workflows/rspec-test.yml) already supports dynamic runtime-balanced shards, but uses its own planner, provisions Rails/Postgres, and expects a caller workflow to publish the historical artifact. [Bullet Train's runtime-log workflow](https://github.com/bullet-train-co/bullet_train-core/blob/main/.github/workflows/_combine_runtime_logs.yml) combines and caches parallel test reports but checks out the Bullet Train starter into a framework-specific directory.

[split-tests-by-timings](https://github.com/r7kamura/split-tests-by-timings) and [split-tests](https://github.com/scruplelesswizard/split-tests) provide reusable splitting actions based on JUnit timing reports. Their consumers still configure history retrieval, test execution, matrix expansion, and report collection/publication. They supply alternative schedulers rather than the missing orchestration around `parallel_tests`.

These are precedents, not functionality to recreate indiscriminately. The project's purpose is the complete, automatic history lifecycle and configurable setup in one consumer workflow while retaining the existing scheduler. Use maintained upstream actions for artifact transport instead of writing replacement upload/download clients.

## One Shared Workflow

A preparation job uses the runner's GitHub CLI to inspect the caller workflow's latest 20 successful default-branch push runs. It skips untrusted runs and expired/missing artifacts and selects one artifact ID. Official artifact actions perform downloads and uploads. API or download failure, missing/expired history, malformed reports, or history covering fewer than half the selected files chooses file-size grouping centrally. Stale paths are discarded. The first successful default-branch run establishes history automatically.

The same preparation job selects files with Ruby's standard glob implementation and generates a JSON array of explicit shard entries, capped at the selected file count. Counts must be integers from 1 through 256; an empty selection fails clearly. A dependent matrix expands that array with `fromJSON` under `matrix.entry`, following [Generating a Task Matrix by Looping over Repo Files with GitHub Actions](https://code.dblock.org/2021/09/03/generating-task-matrix-by-looping-over-repo-files-with-github-actions.html), using `$GITHUB_OUTPUT` instead of the older output syntax. History remains per file, so changing the worker count does not require regenerating it.

Each worker downloads the same immutable artifact containing `plan.json` and a separate historical `runtime.log`. The plan records selected files/sizes, grouping mode, count, and RSpec arguments. After caller setup, the worker verifies the selected file set and sizes have not changed, then invokes the documented `parallel_rspec` CLI with `--only-group`, `--group-by`, `--runtime-log`, and the existing runtime formatter. New files use upstream's average-duration estimation. Historical input is never overwritten by current output; no Ruby or shell code comes from historical artifacts.

After every expected shard succeeds, collection verifies a plan fingerprint, complete shard membership, nonnegative finite durations, selected paths, and no duplicate measurements. An empty successful shard is valid; at least one timing must exist overall. Files without timed example groups remain unknown rather than being assigned fabricated zero durations. Collection runs on PRs too, but only default-branch pushes upload a baseline, and discovery only trusts it once the entire caller workflow succeeds. Optional automatic shard sizing from a target duration is outside the first version.

## Workflow Inputs

| Input             | Default             | Behavior                                                                                                      |
| ---               | ---                 | ---                                                                                                           |
| `ruby-version`    | Empty               | Use the caller's `.ruby-version`, `.tool-versions`, or `mise.toml`; Ruby must satisfy the gem's minimum.      |
| `shards`          | `4`                 | Maximum independent Ubuntu runners; capped at file count.                                                     |
| `pattern`         | `spec/**/*_spec.rb` | Repository-relative Ruby glob; braces support multiple selections.                                            |
| `rspec-options`   | `[]`                | JSON array of RSpec argument strings, not shell code.                                                         |
| `environment`     | `{}`                | JSON environment object for all jobs; use only non-secret values here.                                        |
| `before-bundle`   | Empty               | Shell setup before Ruby/gem installation in preparation, each shard, and collection.                          |
| `setup`           | Empty               | Shell application setup after gem installation in each shard only.                                            |
| `artifacts`       | Empty               | Multiline paths for per-shard coverage, logs, or screenshots; hidden files are retained, even after failures. |
| `artifact-prefix` | `parallel-tests-ci` | Letters/numbers/underscores/hyphens; use distinct prefixes for multiple calls in one caller workflow.         |

An optional `environment` workflow secret supplies a complete JSON environment object instead of the non-secret input. Pass it under the caller job's `secrets` mapping; it replaces, rather than merges with, the input. Secrets stay in job environments, not the shared plan. Do not put secrets in RSpec argument strings or upload paths containing credentials.

Preparation discovers committed specs before application setup. Setup must not add, remove, or change the sizes of selected specs. Use `before-bundle` for native build dependencies and `setup` for database/service preparation; the project does not provision Rails, MongoDB, or Postgres itself. Setup scripts are caller-owned code, not commands taken from artifacts.

Plans, measurements, and optional test artifacts are retained for 30 days; baselines for 90 days, subject to repository retention limits. Plan names include the preparation attempt; dependent jobs use that exact output even when only failed jobs are rerun. Measurements include shard/attempt numbers and a fingerprint of both plan and history. Collection selects the newest successful attempt for each shard belonging to the current plan; older plans cannot fill missing shards. Duplicate reports for one shard/attempt fail. A full rerun creates a new plan artifact instead of overwriting an immutable snapshot.

## Trust and Configuration

PRs, including forks, read trusted default-branch history with a read-only `GITHUB_TOKEN` and never provide future baselines. Normal fork workflow approval still applies. Do not use `pull_request_target`, long-lived tokens, untrusted artifact contents as executable code, or permission escalation.

The caller grants only `contents: read` and `actions: read`. Artifact uploads use GitHub's per-run artifact capability, not a PAT or write-scoped repository token. A failed shard has no successful result marker, uploads no measurement artifact, and cannot produce a baseline; its requested diagnostic artifacts are still retained. Local `RuntimeLog` and `Run` operations do not access GitHub; the `GitHub` module is internal workflow orchestration, not a public CLI.

GitHub failure handling must preserve complete, nonoverlapping test execution. A history optimization cannot justify skipping tests, mixing snapshots, hiding test failures, or publishing partial measurements.
