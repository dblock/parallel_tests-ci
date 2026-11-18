# Design

## Purpose and Status

`parallel_tests-ci` provides reusable CI integration around [parallel_tests](https://github.com/grosser/parallel_tests). The current repository is a gem scaffold with development checks; the timing-history implementation and consumer workflow are not available yet. The following sections define the agreed first-version design, not an implemented API.

Users add the gem and one shared GitHub Actions workflow to their existing project. No manual command, initial measurement run, committed timing report, personal token, or extra service is required. RSpec and GitHub Actions are the only first-version integrations. There is no planned GitLab implementation, hosted service, public CLI, or generic provider framework.

## Reuse the Existing Scheduler

`parallel_tests` owns test execution, timing collection, unknown-runtime estimation, and runtime-based partitioning. Use its documented formatter and command-line options rather than a custom sharding algorithm, monkey patches, internal dependency mutation, or console-output parsing. The project owns only timing-report handling and CI orchestration.

The portable Ruby report layer is separate from GitHub artifact discovery and transport. This keeps the implementation understandable without adding abstractions for hypothetical integrations.

## Existing Integrations

[StrongMind's reusable RSpec workflow](https://github.com/StrongMind/public-reusable-workflows/blob/main/.github/workflows/rspec-test.yml) already supports dynamic runtime-balanced shards, but uses its own planner, provisions Rails/Postgres, and expects a caller workflow to publish the historical artifact. [Bullet Train's runtime-log workflow](https://github.com/bullet-train-co/bullet_train-core/blob/main/.github/workflows/_combine_runtime_logs.yml) combines and caches parallel test reports but checks out the Bullet Train starter into a framework-specific directory.

[split-tests-by-timings](https://github.com/r7kamura/split-tests-by-timings) and [split-tests](https://github.com/scruplelesswizard/split-tests) provide reusable splitting actions based on JUnit timing reports. Their consumers still configure history retrieval, test execution, matrix expansion, and report collection/publication. They supply alternative schedulers rather than the missing orchestration around `parallel_tests`.

These are precedents, not functionality to recreate indiscriminately. The project's purpose is the complete, automatic history lifecycle and configurable setup in one consumer workflow while retaining the existing scheduler. Use maintained upstream actions for artifact transport instead of writing replacement upload/download clients.

## One Shared Workflow

A preparation job selects a retained timing artifact from a successful push to the caller's trusted default branch. It validates the report and chooses one grouping mode for the whole run. Missing, expired, malformed, or insufficient history selects file-size grouping. The first successful default-branch run therefore establishes history automatically.

The same preparation job generates a JSON array of explicit shard entries from the caller's requested count. A dependent matrix expands that array with `fromJSON` under `matrix.entry`, following [Generating a Task Matrix by Looping over Repo Files with GitHub Actions](https://code.dblock.org/2021/09/03/generating-task-matrix-by-looping-over-repo-files-with-github-actions.html), using `$GITHUB_OUTPUT` instead of the older output syntax. Shard names and aggregation use that same count. History remains per file, so changing the worker count does not require regenerating it.

Each worker receives the same immutable history snapshot and grouping mode, performs the caller's setup, and runs its assigned group with the existing RSpec runtime formatter enabled. Historical input is never overwritten by the current shard's output. The shared workflow handles measurement artifacts and preserves configured test and coverage artifacts for caller-owned reporting.

After every expected shard succeeds on the trusted default branch, a final job combines their reports into the next baseline. Duplicate measurements and incomplete shard sets must not silently become authoritative history. Optional automatic shard sizing from a target duration is outside the first version.

## Trust and Configuration

PRs, including forks, read trusted default-branch history with a read-only `GITHUB_TOKEN` and never provide future baselines. Normal fork workflow approval still applies. Do not use `pull_request_target`, long-lived tokens, untrusted artifact contents as executable code, or permission escalation.

The consumer configures Ruby, the shard count, application setup, test environment, and optional RSpec arguments. History preparation, matrix creation, collection, and publication stay internal to one reusable workflow. Application setup remains caller-owned; the project does not introduce database-specific dependencies or take over application coverage reporting.

GitHub failure handling must preserve complete, nonoverlapping test execution. A history optimization cannot justify skipping tests, mixing snapshots, hiding test failures, or publishing partial measurements.
