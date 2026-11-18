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

See [Configuration](README.md#configuration) for inputs and defaults. An empty `ruby-version` uses `.ruby-version`, `.tool-versions`, or `mise.toml`; `pattern` supports Ruby glob braces.

### Worker Templates

| Variable          | Value                                                    |
| ---               | ---                                                      |
| `{shard.number}`  | One-based worker number.                                 |
| `{shard.count}`   | Actual worker count after file-count capping.            |
| `{plan.group_by}` | `runtime` or `filesize`, as selected during preparation. |

| Rule          | Behavior                                                                                                            |
| ---           | ---                                                                                                                 |
| Parent prefix | GitHub adds the caller job's name: `Test / 1 of 8`.                                                                 |
| Evaluation    | Caller expressions resolve first; preparation substitutes variables literally without recursion or code evaluation. |
| Validation    | Braces are reserved; unknown variables, empty placeholders, nested braces, and unmatched braces fail preparation.   |
| Isolation     | Names live in `matrix.entry.name`, outside the timing plan; IDs, assignments, artifacts, and retries are unchanged. |

The caller cannot reference the internal worker matrix directly. Keep gem/workflow refs matched; the gem generates the names consumed by the workflow.

### Environments and Setup

| Setting               | Scope                                                                                     |
| ---                   | ---                                                                                       |
| `environment` input   | Non-secret variables in all jobs.                                                         |
| `secrets.environment` | Complete JSON object replacing, not merging with, the input. Never persisted in the plan. |
| `before-bundle`       | Native dependencies before Ruby/gems in preparation, workers, and collection.             |
| `setup`               | Application services after gems in workers only; no built-in database provisioning.       |

Specs are discovered before application setup; setup must not add, remove, or resize them. Setup scripts are caller-owned, never artifact-supplied. Keep secrets out of RSpec arguments and uploaded files.

| Transport       | Behavior                                                                                                               |
| ---             | ---                                                                                                                    |
| `PTCI_INPUTS`   | `toJSON(inputs)`, parsed once at each Ruby entry point; configuration then passes as explicit arguments.               |
| Types           | Numbers stay numeric; JSON-string inputs such as `rspec-options` are decoded separately.                               |
| Separate values | GitHub metadata, authentication, and the worker's `PTCI_SHARD` remain outside the input object.                        |
| Scope           | Declared inputs only, not workflow secrets or the full GitHub context; Ruby never prints or persists the whole object. |

### Artifacts and Retries

| Item            | Rule                                                                                             |
| ---             | ---                                                                                              |
| Retention       | Plans, measurements, and test artifacts: 30 days; baselines: 90 days, within repository limits.  |
| Shared plan     | Named by preparation attempt; dependent retries reuse that exact snapshot.                       |
| Measurements    | Identify shard, attempt, and plan/history fingerprint; newest successful attempt wins per shard. |
| Invalid reports | Other plans cannot fill missing shards; duplicate shard/attempt reports fail.                    |
| Full rerun      | Creates a new plan artifact without overwriting the old snapshot.                                |

## Trust and Configuration

PRs, including forks, read trusted default-branch history with a read-only `GITHUB_TOKEN` and never provide future baselines. Normal fork workflow approval still applies. Do not use `pull_request_target`, long-lived tokens, untrusted artifact contents as executable code, or permission escalation.

The caller grants only `contents: read` and `actions: read`. Artifact uploads use GitHub's per-run artifact capability, not a PAT or write-scoped repository token. A failed shard has no successful result marker, uploads no measurement artifact, and cannot produce a baseline; its requested diagnostic artifacts are still retained. Local `RuntimeLog` and `Run` operations do not access GitHub; the `GitHub` module is internal workflow orchestration, not a public CLI.

GitHub failure handling must preserve complete, nonoverlapping test execution. A history optimization cannot justify skipping tests, mixing snapshots, hiding test failures, or publishing partial measurements.

## Artwork

The logo pairs one solid blue cube with eight white, blue-outlined cubes, representing a suite divided into independent shards. [assets/logo.svg](assets/logo.svg) is the editable source: complete equal-sized cubes use isometric projection and back-to-front ordering so their volume and overlap remain consistent.

The original project artwork was developed through AI-assisted concept previews followed by precise SVG construction; no third-party artwork was incorporated. It is covered by the project's MIT license. Keep the SVG and its [PNG rendering](assets/logo.png) together. With librsvg installed, regenerate the PNG from the repository root:

```sh
rsvg-convert --output assets/logo.png assets/logo.svg
```
