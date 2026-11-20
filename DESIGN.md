# Design

## Scope

The gem validates plans and timing reports; `.github/workflows/shards.yml` handles GitHub Actions jobs and artifacts. [parallel_tests](https://github.com/grosser/parallel_tests) owns partitioning, timing collection, and unknown-runtime estimation. Use its documented API and formatter, not a custom scheduler or console parsing.

Scope is RSpec and Minitest on GitHub Actions, without a hosted service, public CLI, or other-provider abstraction. Automatic shard sizing is not implemented.

`rspec.yml` and `minitest.yml` pass their framework, file pattern, and artifact prefix to `shards.yml`. The immutable plan selects `parallel_test` for Minitest. The `parallel_tests/ci/minitest` entry point uses `PTCI_RUNTIME_LOG` to enable the upstream logger and write measurements separately from restored history. Minitest 6 changed the runner hooks used by that logger; use Minitest 5.

Each runner defines its default file glob, test command, and timing output. The base runner builds and executes the shared `parallel_tests` command. The run lifecycle selects files, chooses a grouping mode, and validates reports; `parallel_tests` still decides which files belong to each shard. GitHub matrix, artifact, and trust rules do not depend on the runner. Runners are not a public extension API.

## Standalone Shard Matrix Action

The [standalone action](README.md#standalone-shard-matrix-action) uses the same file discovery, timing validation, and upstream partitioner as the reusable workflow. `framework` selects `rspec` (the default) or `minitest`; an empty `pattern` uses the selected framework's default glob. It does not create jobs, run tests, or manage timing artifacts.

Set up Ruby and install `parallel_tests` in the caller's bundle before invoking the action. The optional `runtime-log` input points to a local timing log; an empty value supplies no history. `group-by` accepts `auto` (the default), `filesize`, or `runtime`, with the same coverage requirements as the reusable workflows.

`shards` defaults to `4`, accepts `1` through `256`, and is capped at the number of matching files. No matches fail the step. The JSON `matrix` output contains one-based `shard` numbers and `files` arrays of repository-relative paths. Empty groups are omitted. The `group-by` output is `filesize` or `runtime`. GitHub's job output size limits apply to the file lists.

## Workflow

| Job     | Behavior                                                         |
| ---     | ---                                                              |
| Prepare | Find a timing baseline and emit the `matrix.entry` plan.         |
| Test    | Run each planned shard and mark it successful only if it passes. |
| Collect | Validate and combine all shards' timings into a baseline.        |

Unless `group-by` is `filesize`, Prepare looks for a retained baseline among the caller workflow's latest 20 successful default-branch pushes. It rejects empty selections, caps the requested 1-256 shards at the file count, and writes the matrix to `$GITHUB_OUTPUT`. Runtime grouping drops stale paths and requires timings for at least half the selected files; upstream estimates unknown durations. If there are insufficient timings, `auto` falls back to file sizes and `runtime` fails. Per-file history survives worker-count changes.

### Plans and Retries

`plan.json` records test paths and sizes, grouping, shard count, and test framework arguments. Its exact bytes and those of the historical `runtime.log` determine the SHA256 fingerprint. Workers download both, run caller setup, reject changed paths or sizes, and call the selected `parallel_tests` runner with `--only-group`, `--group-by`, and `--runtime-log`. Collect uses each shard's newest successful report and requires matching fingerprints, selected paths, and finite nonnegative durations.

| Case                     | Rule                                                                                                         |
| ---                      | ---                                                                                                          |
| Failed shard             | No success marker or measurement upload; requested diagnostics are still retained.                           |
| Failed-job retry         | Reuse the prepared plan; select the newest successful numeric attempt per shard.                             |
| Duplicate latest attempt | Fail collection rather than choose arbitrarily.                                                              |
| Full rerun               | Create a new preparation-attempt artifact. Never fill gaps from another fingerprint.                         |
| Empty shard              | Valid, but collection requires at least one timing overall. Missing timings stay unknown, not zero-duration. |

Official artifact actions handle transport. Retention is configured separately for run artifacts and trusted baselines; repository limits apply.

Extra artifact paths can include hidden files and are collected even after a worker fails. Use a unique prefix for each workflow call, with only letters, numbers, underscores, and hyphens.

## Workflow Inputs

See [Configuration](README.md#configuration) for every input and default. Keep gem/workflow versions matched. Ruby defaults to `.ruby-version`, `.tool-versions`, or `mise.toml`; spec patterns use Ruby globs, including braces.

### Runners and Execution

All jobs use `runs-on`: a label such as `macos-latest` or JSON labels such as `'["self-hosted","linux","x64"]'`. Linux and macOS are supported, not Windows. Custom runners need Bash, Git, the GitHub CLI, and compatibility with the pinned actions and `ruby/setup-ruby`.

Job timeouts include setup and remain subject to runner limits. `max-parallel` limits concurrent workers, not total shards. `fail-fast` cannot publish an incomplete baseline. Configure workflow concurrency in the caller; working directories, containers, and services are not inputs.

### Worker Templates

| Variable          | Value                                                    |
| ---               | ---                                                      |
| `{shard.number}`  | One-based worker number.                                 |
| `{shard.count}`   | Actual worker count after file-count capping.            |
| `{plan.group_by}` | `runtime` or `filesize`, as selected during preparation. |

For example, `worker-name: 'RSpec {shard.number}/{shard.count} ({plan.group_by})'` yields `Test / RSpec 1/8 (runtime)`. GitHub supplies the caller prefix. Caller expressions resolve first but cannot access the internal worker matrix; template substitution is literal, without recursion.

An empty `worker-name` uses the default. Braces are reserved: unknown, empty, nested, or unmatched placeholders fail preparation. Labels live only in `matrix.entry.name`, not the plan or fingerprint.

### Environments and Setup

`environment` supplies non-secret JSON variables to every job. `secrets.environment` replaces that entire object, never merges with it. Neither secrets nor setup scripts come from artifacts.

Run native dependency setup in `before-bundle` before Ruby/gems in all jobs. `setup` runs after gems in workers only; provision application services there. Do not add, remove, or resize selected specs. Keep secrets out of test arguments and uploaded files.

`PTCI_INPUTS` carries `toJSON(inputs)`, parsed once per Ruby entry point and passed explicitly thereafter. Numeric types survive; JSON-string inputs are decoded separately. GitHub metadata/authentication and `PTCI_SHARD` stay separate. Ruby never logs or persists the entire input object.

## Trust

PRs, including forks, read history but never supply baselines. Only successful same-repository, same-workflow default-branch push runs are trusted. Normal fork approval applies. Use `contents: read` and `actions: read`; artifact uploads need no extra token. Never persist checkout credentials, execute artifacts, use `pull_request_target`, or hide failures to publish partial history.

Portable `Run` and `RuntimeLog` operations do not access GitHub. The internal `GitHub` adapter handles metadata and transport.

## Artwork

The original AI-assisted logo is MIT-licensed, with no third-party artwork. A single perspective camera projects the solid cube and eight separated small cubes; faces are painted back to front. The Test badge supplies greens `#34D058` and `#28A745`, with a darker side and lightly shaded white faces. Keep the editable [SVG](assets/logo.svg) and [PNG](assets/logo.png) together. Render from the repository root with librsvg:

```sh
rsvg-convert --output assets/logo.png assets/logo.svg
```

The original MIT-licensed [demo chart](assets/demo.svg) plots each run's slowest successful worker's RSpec `Finished in` duration, excluding setup and file loading. Source runs are linked in README. Keep its PNG synchronized:

```sh
rsvg-convert --output assets/demo.png assets/demo.svg
```
