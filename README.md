<img src="assets/logo.svg" alt="A solid green cube beside eight outlined cubes in perspective" width="160">

# Parallel Tests CI

[![Gem Version](https://img.shields.io/gem/v/parallel_tests-ci.svg)](https://rubygems.org/gems/parallel_tests-ci) [![Test](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml) [![Lint](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml) [![Package](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml) [![Coverage](https://coveralls.io/repos/github/dblock/parallel_tests-ci/badge.svg?branch=master)](https://coveralls.io/github/dblock/parallel_tests-ci?branch=master)

Runtime-balanced RSpec and Minitest shards for GitHub Actions, powered by [parallel_tests](https://github.com/grosser/parallel_tests). Timing history is collected and reused automatically.

## Usage

Requires Ruby 3.3+ and either RSpec or Minitest 5.

### RSpec

Add to your Gemfile and run `bundle install`:

```ruby
gem 'parallel_tests-ci', '0.2.1', require: 'parallel_tests/ci/rspec'
```

RSpec matches `spec/**/*_spec.rb` by default and records timings automatically; no changes to `spec_helper.rb` are needed.

Add `.github/workflows/test.yml`:

```yaml
name: Test
on: [push, pull_request]

permissions:
  contents: read
  actions: read

jobs:
  test:
    name: Test
    uses: dblock/parallel_tests-ci/.github/workflows/rspec.yml@v0.2.1
    with:
      shards: 8
```

### Minitest

Add to your Gemfile and run `bundle install`:

```ruby
gem 'parallel_tests-ci', '0.2.1', require: 'parallel_tests/ci/minitest'
```

Minitest matches `test/**/*_test.rb` by default. If your test boot does not call `Bundler.require`, add `require 'parallel_tests/ci/minitest'` to `test_helper.rb`. The timing hook only activates in shard workers.

Add `.github/workflows/test.yml`:

```yaml
name: Test
on: [push, pull_request]

permissions:
  contents: read
  actions: read

jobs:
  test:
    name: Test
    uses: dblock/parallel_tests-ci/.github/workflows/minitest.yml@v0.2.1
    with:
      shards: 8
```

### Standalone Shard Matrix Action

If you manage your own CI jobs, use [the standalone action](DESIGN.md#standalone-shard-matrix-action) to plan RSpec or Minitest shards. It defaults to RSpec; set `framework: minitest` for Minitest. See the [RSpec](.github/workflows/test-standalone-rspec.yml) and [Minitest](.github/workflows/test-standalone-minitest.yml) examples, replacing `uses: ./` with `uses: dblock/parallel_tests-ci@v0.2.1`. Unlike the reusable workflows, the standalone action only assigns files to shards; your workflow runs the tests and manages timing history.

## Configuration

The workflow uses Ruby from your version file and defaults to Ubuntu; set `runs-on` to use macOS or Windows runners. The first run groups tests by file size. Successful pushes on the default branch record timings for later runs, and PRs read them without updating history.

These inputs configure the reusable workflows.

### Runners and Execution

| Input             | Default         | Purpose                                             |
| ---               | ---             | ---                                                 |
| `runs-on`         | `ubuntu-latest` | Runner label, JSON label array, or group object.    |
| `timeout-minutes` | `360`           | Minutes per job, including setup; positive integer. |
| `max-parallel`    | `256`           | Concurrent worker limit (1-256).                    |
| `fail-fast`       | `false`         | Cancel remaining workers on failure.                |
| `fetch-depth`     | `1`             | Checkout depth; `0` gets all history and tags.      |
| `ruby-version`    | Empty           | Override Ruby; `system` uses the runner's Ruby.     |
| `bundler-cache`   | `true`          | Cache gems; `false` or `system` installs uncached.  |

### Suite and Setup

| Input           | Default                                                     | Purpose                                     |
| ---             | ---                                                         | ---                                         |
| `shards`        | `4`                                                         | Workers (1-256), capped at test file count. |
| `worker-name`   | `{shard.number} of {shard.count}`                           | Worker label template.                      |
| `pattern`       | `spec/**/*_spec.rb` (RSpec), `test/**/*_test.rb` (Minitest) | Repository-relative test glob.              |
| `test-options`  | `[]`                                                        | Test framework arguments as a JSON array.   |
| `environment`   | `{}`                                                        | Non-secret env vars as a JSON object.       |
| `before-bundle` | Empty                                                       | Shell setup before gem install in all jobs. |
| `setup`         | Empty                                                       | Shell setup before tests in each worker.    |

Use arguments supported by the selected framework, for example `test-options: '["--seed","123"]'`. The `before-bundle` and `setup` scripts run with the runner's default shell: Bash on Linux and macOS, and PowerShell on Windows. To share one Bash script across operating systems, call `bash -c` from it, since Windows runners also provide Git Bash.

### Shard Grouping

| Input      | Default | Purpose                                  |
| ---        | ---     | ---                                      |
| `group-by` | `auto`  | Choose `auto`, `filesize`, or `runtime`. |

- `auto`: Use runtime history when usable timings cover at least half the selected files. Otherwise, group by file size.
- `filesize`: Group by file size without reading timing history. Reusable workflows still collect fresh timings.
- `runtime`: Group by runtime. Planning fails if usable timings cover fewer than half the selected files.

### Artifacts

| Input                     | Default             | Purpose                                             |
| ---                       | ---                 | ---                                                 |
| `artifacts`               | Empty               | Extra files to keep, even on failure.               |
| `artifact-prefix`         | `parallel-tests-ci` | Artifact name prefix; unique per call.              |
| `artifact-retention-days` | `30`                | Days to keep run artifacts; `0` uses repo default.  |
| `baseline-retention-days` | `90`                | Days to keep timing history; `0` uses repo default. |

See [Workflow Inputs](DESIGN.md#workflow-inputs) for templates, secret environments, and setup rules, and [Plans and Retries](DESIGN.md#plans-and-retries) for rerun behavior.

## Demo

[Posebook](https://github.com/dblock/posebook) runs 1,142 examples across eight workers. Times are for the slowest successful RSpec worker, excluding setup and spec loading.

<img src="assets/demo.svg" alt="Slowest worker RSpec time: serial 395s, custom sharding 61.62s, parallel_tests alone 70.71s, parallel_tests-ci cold run 79.11s, warm run 57.59s" width="480">

- [Serial run](https://github.com/dblock/posebook/actions/runs/44218105420): 395s.
- [Custom sharding #178](https://github.com/dblock/posebook/pull/178): 61.62s.
- [`parallel_tests` alone #181](https://github.com/dblock/posebook/pull/181): 70.71s.
- [Cold run #185](https://github.com/dblock/posebook/pull/185): 79.11s.
- [Warm run #187](https://github.com/dblock/posebook/pull/187): 57.59s; timings for 85/95 files.

## Contributing

See [Contributing](CONTRIBUTING.md), [Coding Guidance](AGENTS.md), [Design](DESIGN.md), [Changelog](CHANGELOG.md), [Releasing](RELEASING.md), and [Upgrading](UPGRADING.md).

## License

Distributed under the [MIT License](LICENSE.txt).
