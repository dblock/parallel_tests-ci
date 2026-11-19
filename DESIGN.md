# Design

## Scope

The gem validates plans and timing reports; `.github/workflows/rspec.yml` handles GitHub Actions jobs and artifacts. [parallel_tests](https://github.com/grosser/parallel_tests) owns partitioning, timing collection, and unknown-runtime estimation. Use its documented API and formatter, not a custom scheduler or console parsing.

Scope is RSpec on GitHub Actions, without a hosted service, public CLI, or other-provider abstraction. Automatic shard sizing is not implemented.

## Standalone Shard Matrix Action

The [standalone action](README.md#standalone-shard-matrix-action) uses the same file discovery, timing validation, and upstream partitioner as the reusable workflow. It does not create jobs, run tests, or manage timing artifacts.

`shards` defaults to `4`, accepts `1` through `256`, and is capped at the number of matching files. No matches fail the step. The JSON `matrix` output contains one-based `shard` numbers and `files` arrays of repository-relative paths. Empty groups are omitted. The `group-by` output is `filesize` or `runtime`. GitHub's job output size limits apply to the file lists.

## Workflow

| Job     | Behavior                                                                                                                                                                                                                                  |
| ---     | ---                                                                                                                                                                                                                                       |
| Prepare | Inspect the caller workflow's latest 20 successful default-branch push runs for a retained baseline. Select files, cap the requested 1-256 shards at file count, and emit `matrix.entry` through `$GITHUB_OUTPUT`. Empty selections fail. |
| Test    | Download the immutable plan/history, run caller setup, reject changed spec paths/sizes, and invoke `parallel_rspec` with `--only-group`, `--group-by`, and `--runtime-log`. Write a success marker only after passing tests.              |
| Collect | Require every shard, matching fingerprints, selected paths, and finite nonnegative durations. Combine the newest successful attempt per shard; publish history only on default-branch pushes.                                             |

Missing, expired, malformed, or inaccessible history falls back centrally to file sizes. Runtime grouping requires timings for at least half the selected files; stale paths are discarded. Unknown files use upstream's average-duration estimate. History stays per file, so worker-count changes do not invalidate it.

### Plans and Retries

`plan.json` records selected paths/sizes, grouping, shard count, and RSpec arguments. Its historical `runtime.log` is separate from worker output; their exact bytes determine the SHA256 fingerprint.

| Case                     | Rule                                                                                                         |
| ---                      | ---                                                                                                          |
| Failed shard             | No success marker or measurement upload; requested diagnostics are still retained.                           |
| Failed-job retry         | Reuse the prepared plan; select the newest successful numeric attempt per shard.                             |
| Duplicate latest attempt | Fail collection rather than choose arbitrarily.                                                              |
| Full rerun               | Create a new preparation-attempt artifact. Never fill gaps from another fingerprint.                         |
| Empty shard              | Valid, but collection requires at least one timing overall. Missing timings stay unknown, not zero-duration. |

Official artifact actions handle transport. Retention is configured separately for run artifacts and trusted baselines; repository limits apply.

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

Braces are reserved: unknown, empty, nested, or unmatched placeholders fail preparation. Labels live only in `matrix.entry.name`, not the plan or fingerprint.

### Environments and Setup

`environment` supplies non-secret JSON variables to every job. `secrets.environment` replaces that entire object, never merges with it. Neither secrets nor setup scripts come from artifacts.

Run native dependency setup in `before-bundle` before Ruby/gems in all jobs. `setup` runs after gems in workers only; provision application services there. Do not add, remove, or resize selected specs. Keep secrets out of RSpec arguments and uploaded files.

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
